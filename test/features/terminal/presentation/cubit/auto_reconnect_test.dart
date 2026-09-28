import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sshku/core/platform/dart_ssh_service.dart';
import 'package:sshku/features/terminal/presentation/cubit/terminal_cubit.dart';
import 'package:sshku/features/terminal/presentation/cubit/terminal_state.dart';

/// Fake SshService: mengontrol outputStream (untuk memicu disconnect) dan bisa
/// dibuat gagal saat connect. Tidak menyentuh isolate/jaringan nyata.
class FakeSshService implements SshService {
  int connectCount = 0;
  bool shouldFail = false;
  StreamController<String> _controller = StreamController<String>.broadcast();

  void emitDone() => _controller.close();

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
    connectCount++;
    if (shouldFail) throw Exception('Connection failed');
    // Reconnect sukses: siapkan stream baru agar bisa dipicu putus lagi.
    if (_controller.isClosed) {
      _controller = StreamController<String>.broadcast();
    }
  }

  @override
  Future<void> openShell({int cols = 80, int rows = 24}) async {}

  @override
  void sendInput(String input) {}

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

  late FakeSshService fakeSsh;

  setUp(() {
    fakeSsh = FakeSshService();
  });

  Future<void> reachActive(TerminalCubit cubit) async {
    await cubit.connectAndOpenShell('host', 22, 'user', password: 'pass');
    // getKnownHost mengembalikan null -> HostKeyPrompt
    if (cubit.state is TerminalHostKeyPrompt) {
      await cubit.acceptHostKeyAndConnect(
          fingerprint: 'abc123', keyType: 'ed25519');
    }
    expect(cubit.state, isA<TerminalActive>());
  }

  test('on disconnect, cubit emits TerminalReconnecting and reconnects', () async {
    final cubit = TerminalCubit(ssh: fakeSsh);
    final states = <TerminalState>[];
    final sub = cubit.stream.listen(states.add);

    await reachActive(cubit);
    fakeSsh.connectCount = 0;
    states.clear();

    fakeSsh.emitDone(); // picu disconnect
    await Future.delayed(const Duration(seconds: 5));

    expect(fakeSsh.connectCount, greaterThan(0));
    expect(states, contains(isA<TerminalReconnecting>()));

    await sub.cancel();
    await cubit.close();
  });

  test('after 3 failed retries, transitions to TerminalDisconnected', () async {
    final cubit = TerminalCubit(ssh: fakeSsh);
    final states = <TerminalState>[];
    final sub = cubit.stream.listen(states.add);

    await reachActive(cubit);
    fakeSsh.shouldFail = true;
    fakeSsh.connectCount = 0;
    states.clear();

    fakeSsh.emitDone();
    // Tunggu 3 percobaan: delay 2s + 4s + 8s = 14s + margin.
    await Future.delayed(const Duration(seconds: 16));

    expect(fakeSsh.connectCount, 3);
    expect(cubit.state, isA<TerminalDisconnected>());

    await sub.cancel();
    await cubit.close();
  }, timeout: const Timeout(Duration(seconds: 25)));
}
