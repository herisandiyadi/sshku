import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sshku/core/platform/shell_event_channel.dart';
import 'package:sshku/core/platform/ssh_platform_channel.dart';
import 'package:sshku/features/terminal/presentation/cubit/terminal_cubit.dart';
import 'package:sshku/features/terminal/presentation/cubit/terminal_state.dart';

// Manual mocks
class MockSshPlatformChannel extends SshPlatformChannel {
  int connectCount = 0;
  bool shouldFail = false;

  @override
  Future<String> connect({
    required String host,
    required int port,
    required String username,
    String? password,
    String? privateKey,
    bool acceptHostKey = false,
  }) async {
    connectCount++;
    if (shouldFail) throw Exception('Connection failed');
    return 'session-1';
  }

  @override
  Future<Map<String, String>> getHostFingerprint({
    required String host,
    required int port,
  }) async =>
      {'fingerprint': 'abc123', 'keyType': 'ed25519'};

  @override
  Future<void> openShell(String sessionId) async {}

  @override
  Future<void> closeShell(String sessionId) async {}

  @override
  Future<void> sendInput(String sessionId, String input) async {}

  @override
  Future<void> resizeShell(String sessionId, int cols, int rows) async {}
}

class MockShellEventChannel extends ShellEventChannel {
  StreamController<String>? _controller;

  void init() => _controller = StreamController<String>.broadcast();

  @override
  Stream<String> get outputStream => _controller!.stream;

  void emitDone() => _controller!.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late MockSshPlatformChannel mockSsh;
  late MockShellEventChannel mockShell;

  setUp(() {
    mockSsh = MockSshPlatformChannel();
    mockShell = MockShellEventChannel();
    mockShell.init();
  });

  test('on disconnect, cubit emits TerminalReconnecting states', () async {
    final cubit = TerminalCubit(
      sshChannel: mockSsh,
      shellEventChannel: mockShell,
    );

    final states = <TerminalState>[];
    final sub = cubit.stream.listen(states.add);

    await cubit.connectAndOpenShell('host', 22, 'user', password: 'pass');

    // getKnownHost returns null -> HostKeyPrompt
    if (cubit.state is TerminalHostKeyPrompt) {
      await cubit.acceptHostKeyAndConnect(
          fingerprint: 'abc123', keyType: 'ed25519');
    }

    expect(cubit.state, isA<TerminalActive>());
    mockSsh.connectCount = 0;
    states.clear();

    // Trigger disconnect
    mockShell.emitDone();
    await Future.delayed(const Duration(seconds: 5));

    expect(mockSsh.connectCount, greaterThan(0));
    expect(states, contains(isA<TerminalReconnecting>()));

    await sub.cancel();
    await cubit.close();
  });

  test('after 3 failures, transitions to TerminalDisconnected', () async {
    final cubit = TerminalCubit(
      sshChannel: mockSsh,
      shellEventChannel: mockShell,
    );

    final states = <TerminalState>[];
    final sub = cubit.stream.listen(states.add);

    await cubit.connectAndOpenShell('host', 22, 'user', password: 'pass');
    if (cubit.state is TerminalHostKeyPrompt) {
      await cubit.acceptHostKeyAndConnect(
          fingerprint: 'abc123', keyType: 'ed25519');
    }

    expect(cubit.state, isA<TerminalActive>());
    mockSsh.shouldFail = true;
    mockSsh.connectCount = 0;
    states.clear();

    mockShell.emitDone();
    // Wait for all 3 retry attempts (2s + 4s + 8s = 14s + margin)
    await Future.delayed(const Duration(seconds: 16));

    expect(mockSsh.connectCount, 3);
    expect(cubit.state, isA<TerminalDisconnected>());

    await sub.cancel();
    await cubit.close();
  }, timeout: const Timeout(Duration(seconds: 25)));
}
