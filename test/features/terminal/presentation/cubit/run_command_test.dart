import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sshku/core/database/database_helper.dart';
import 'package:sshku/core/platform/dart_ssh_service.dart';
import 'package:sshku/features/terminal/presentation/cubit/terminal_cubit.dart';
import 'package:sshku/features/terminal/presentation/cubit/terminal_state.dart';

/// Fake yang merekam setiap input yang dikirim ke shell.
class RecordingSshService implements SshService {
  final List<String> inputs = [];
  StreamController<String> _controller = StreamController<String>.broadcast();

  @override
  Stream<String> get outputStream => _controller.stream;

  @override
  Future<Map<String, String>> getHostFingerprintMap({
    required String host,
    required int port,
  }) async =>
      {'fingerprint': 'abc123', 'keyType': 'ed25519'};

  @override
  Future<void> connect({
    required String host,
    required int port,
    required String username,
    String? password,
    String? privateKey,
  }) async {
    if (_controller.isClosed) {
      _controller = StreamController<String>.broadcast();
    }
  }

  @override
  Future<void> openShell({int cols = 80, int rows = 24}) async {}

  @override
  void sendInput(String input) => inputs.add(input);

  @override
  void resize(int cols, int rows) {}

  @override
  Future<void> close() async {}

  @override
  void dispose() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late RecordingSshService fakeSsh;
  late TerminalCubit cubit;

  setUp(() async {
    fakeSsh = RecordingSshService();
    cubit = TerminalCubit(ssh: fakeSsh);
    await cubit.connectAndOpenShell('runcmd-host', 22, 'user', password: 'pass');
    if (cubit.state is TerminalHostKeyPrompt) {
      await cubit.acceptHostKeyAndConnect(
          fingerprint: 'abc123', keyType: 'ed25519');
    }
    // Bersihkan history sisa test lain agar hitungan akurat.
    await DatabaseHelper.instance.clearHistory();
  });

  tearDown(() async {
    await cubit.close();
  });

  test('runCommand mengirim command + carriage return ke shell', () {
    fakeSsh.inputs.clear();
    cubit.runCommand('systemctl status nginx');
    expect(fakeSsh.inputs, ['systemctl status nginx\r']);
  });

  test('runCommand mencatat command ke history tepat satu kali', () async {
    cubit.runCommand('uptime');
    final history = await DatabaseHelper.instance.getHistory();
    final matches = history.where((h) => h.command == 'uptime').toList();
    expect(matches, hasLength(1));
    expect(matches.first.serverHost, 'runcmd-host');
  });

  test('runCommand tidak merusak keystroke manual berikutnya', () async {
    // Simulasi user mengetik "ls" lalu Enter setelah AI menjalankan command.
    cubit.runCommand('whoami');
    cubit.sendInput('l');
    cubit.sendInput('s');
    cubit.sendInput('\r');

    final history = await DatabaseHelper.instance.getHistory();
    final commands = history.map((h) => h.command).toList();
    // Baris manual harus tercatat sebagai 'ls' murni, bukan 'whoami\rls'.
    expect(commands, contains('ls'));
    expect(commands.any((c) => c.contains('whoami\r') || c.contains('whoamils')),
        isFalse);
  });

  test('runCommand mengabaikan input kosong', () {
    fakeSsh.inputs.clear();
    cubit.runCommand('   ');
    expect(fakeSsh.inputs, isEmpty);
  });
}
