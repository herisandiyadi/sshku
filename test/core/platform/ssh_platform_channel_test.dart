import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sshku/core/platform/ssh_platform_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SshPlatformChannel sshChannel;
  final List<MethodCall> log = [];

  setUp(() {
    sshChannel = SshPlatformChannel();
    log.clear();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.example.sshku/ssh'),
      (MethodCall methodCall) async {
        log.add(methodCall);
        switch (methodCall.method) {
          case 'connect':
            return 'session-abc';
          case 'disconnect':
            return true;
          case 'execute':
            return 'output';
          default:
            return null;
        }
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.example.sshku/ssh'),
      null,
    );
  });

  test('connect() invokes correct method with params', () async {
    final result = await sshChannel.connect(
      host: '10.0.0.1',
      port: 22,
      username: 'user',
      password: 'pass',
    );

    expect(result, 'session-abc');
    expect(log.single.method, 'connect');
    expect(log.single.arguments['host'], '10.0.0.1');
    expect(log.single.arguments['port'], 22);
    expect(log.single.arguments['username'], 'user');
    expect(log.single.arguments['password'], 'pass');
  });

  test('disconnect() invokes correct method', () async {
    final result = await sshChannel.disconnect('session-abc');

    expect(result, true);
    expect(log.single.method, 'disconnect');
    expect(log.single.arguments['sessionId'], 'session-abc');
  });

  test('execute() invokes correct method', () async {
    final result = await sshChannel.execute('session-abc', 'ls -la');

    expect(result, 'output');
    expect(log.single.method, 'execute');
    expect(log.single.arguments['sessionId'], 'session-abc');
    expect(log.single.arguments['command'], 'ls -la');
  });
}
