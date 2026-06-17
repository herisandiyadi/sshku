import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';

/// SSH service that runs all SSH operations in a background isolate
/// to prevent ANR caused by dartssh2 key exchange blocking the main thread.
class DartSshService {
  Isolate? _isolate;
  SendPort? _cmdPort;
  ReceivePort? _receivePort;
  final _outputController = StreamController<String>.broadcast();
  final _completers = <int, Completer<dynamic>>{};
  int _nextId = 0;

  Stream<String> get outputStream => _outputController.stream;

  DartSshService() {
    // Eagerly spawn isolate to avoid delay at first command
    _ensureIsolate();
  }

  Future<Map<String, String>> getHostFingerprintMap({
    required String host,
    required int port,
  }) async {
    final result = await _send('fingerprint', {'host': host, 'port': port});
    return Map<String, String>.from(result as Map);
  }

  Future<void> connect({
    required String host,
    required int port,
    required String username,
    String? password,
    String? privateKey,
  }) async {
    await _send('connect', {
      'host': host,
      'port': port,
      'username': username,
      'password': password,
      'privateKey': privateKey,
    });
  }

  Future<void> openShell({int cols = 80, int rows = 24}) async {
    await _send('openShell', {'cols': cols, 'rows': rows});
  }

  Future<String> execute(String command) async {
    final result = await _send('execute', {'command': command});
    return result as String;
  }

  void sendInput(String input) {
    _cmdPort?.send({'cmd': 'input', 'data': input});
  }

  void resize(int cols, int rows) {
    _cmdPort?.send({'cmd': 'resize', 'cols': cols, 'rows': rows});
  }

  Future<void> close() async {
    try {
      _cmdPort?.send({'cmd': 'close'});
      // Give isolate time to cleanup
      await Future.delayed(const Duration(milliseconds: 200));
    } catch (_) {}
    _killIsolate();
  }

  void dispose() {
    _cmdPort?.send({'cmd': 'close'});
    Future.delayed(const Duration(milliseconds: 100), _killIsolate);
    if (!_outputController.isClosed) _outputController.close();
  }

  void _killIsolate() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _cmdPort = null;
    _receivePort?.close();
    _receivePort = null;
    // Fail any pending completers
    for (final c in _completers.values) {
      if (!c.isCompleted) c.completeError(Exception('Isolate terminated'));
    }
    _completers.clear();
  }

  /// Send a command and wait for response
  Future<dynamic> _send(String cmd, Map<String, dynamic> args) async {
    await _ensureIsolate();
    final id = _nextId++;
    final completer = Completer<dynamic>();
    _completers[id] = completer;
    _cmdPort!.send({'id': id, 'cmd': cmd, ...args});
    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        _completers.remove(id);
        throw TimeoutException('SSH operation "$cmd" timed out');
      },
    );
  }

  Future<void> _ensureIsolate() async {
    if (_isolate != null && _cmdPort != null) return;

    _receivePort = ReceivePort();
    _isolate = await Isolate.spawn(
      _isolateMain,
      _receivePort!.sendPort,
      debugName: 'ssh_isolate',
    );

    final readyCompleter = Completer<SendPort>();

    _receivePort!.listen((msg) {
      if (msg is SendPort) {
        readyCompleter.complete(msg);
        return;
      }
      if (msg is Map) {
        _handleMessage(msg);
      }
    });

    _cmdPort = await readyCompleter.future;
  }

  void _handleMessage(Map msg) {
    final type = msg['type'] as String?;

    switch (type) {
      case 'response':
        final id = msg['id'] as int;
        final completer = _completers.remove(id);
        if (completer == null || completer.isCompleted) return;
        if (msg.containsKey('error')) {
          completer.completeError(Exception(msg['error'] as String));
        } else {
          completer.complete(msg['result']);
        }
      case 'output':
        if (!_outputController.isClosed) {
          _outputController.add(msg['data'] as String);
        }
      case 'done':
        if (!_outputController.isClosed) _outputController.close();
    }
  }

  // ─── Isolate entry point ───────────────────────────────────────────

  static void _isolateMain(SendPort mainPort) {
    final cmdPort = ReceivePort();
    mainPort.send(cmdPort.sendPort);
    debugPrint('[SSH_ISOLATE] Isolate started and ready');

    SSHClient? client;
    SSHSession? shell;

    cmdPort.listen((msg) async {
      if (msg is! Map) return;
      final cmd = msg['cmd'] as String;
      final id = msg['id'] as int?;

      switch (cmd) {
        case 'fingerprint':
          try {
            final host = msg['host'] as String;
            final port = msg['port'] as int;
            String? fingerprint;
            String? keyType;

            final socket = await SSHSocket.connect(host, port,
                timeout: const Duration(seconds: 10));
            final probe = SSHClient(
              socket,
              username: 'probe',
              onVerifyHostKey: (type, hk) {
                keyType = type;
                fingerprint = base64.encode(hk);
                return true;
              },
              onPasswordRequest: () => '',
            );
            try {
              await probe.authenticated.timeout(const Duration(seconds: 10));
            } catch (_) {}
            probe.close();
            await probe.done.catchError((_) {});

            if (fingerprint == null) {
              mainPort.send({'type': 'response', 'id': id, 'error': 'Could not retrieve host key'});
            } else {
              mainPort.send({'type': 'response', 'id': id, 'result': {'fingerprint': fingerprint!, 'keyType': keyType ?? 'unknown'}});
            }
          } catch (e) {
            mainPort.send({'type': 'response', 'id': id, 'error': e.toString()});
          }

        case 'connect':
          try {
            final host = msg['host'] as String;
            final port = msg['port'] as int;
            final username = msg['username'] as String;
            final password = msg['password'] as String?;
            final privateKey = msg['privateKey'] as String?;
            debugPrint('[SSH_ISOLATE] Connecting to $host:$port...');

            final socket = await SSHSocket.connect(host, port,
                timeout: const Duration(seconds: 10));
            debugPrint('[SSH_ISOLATE] Socket connected, starting auth...');
            client = SSHClient(
              socket,
              username: username,
              onVerifyHostKey: (_, __) => true,
              onPasswordRequest: password != null ? () => password : null,
              identities: privateKey != null ? _parseKey(privateKey) : null,
            );
            await client!.authenticated;
            debugPrint('[SSH_ISOLATE] Authenticated OK');
            mainPort.send({'type': 'response', 'id': id, 'result': null});
          } catch (e) {
            debugPrint('[SSH_ISOLATE] Connect error: $e');
            mainPort.send({'type': 'response', 'id': id, 'error': e.toString()});
          }

        case 'openShell':
          try {
            final cols = msg['cols'] as int;
            final rows = msg['rows'] as int;
            shell = await client!.shell(
              pty: SSHPtyConfig(type: 'xterm-256color', width: cols, height: rows),
            );
            mainPort.send({'type': 'response', 'id': id, 'result': null});

            // Batch output in isolate to avoid flooding main isolate ReceivePort
            final outBuf = StringBuffer();
            Timer? flushTimer;

            void flush() {
              flushTimer = null;
              if (outBuf.isNotEmpty) {
                mainPort.send({'type': 'output', 'data': outBuf.toString()});
                outBuf.clear();
              }
            }

            shell!.stdout.listen(
              (data) {
                outBuf.write(utf8.decode(data, allowMalformed: true));
                flushTimer ??= Timer(const Duration(milliseconds: 32), flush);
              },
              onDone: () {
                flush();
                mainPort.send({'type': 'done'});
              },
            );
            shell!.stderr.listen(
              (data) {
                outBuf.write(utf8.decode(data, allowMalformed: true));
                flushTimer ??= Timer(const Duration(milliseconds: 32), flush);
              },
            );
          } catch (e) {
            mainPort.send({'type': 'response', 'id': id, 'error': e.toString()});
          }

        case 'execute':
          try {
            final command = msg['command'] as String;
            final result = await client!.run(command);
            mainPort.send({'type': 'response', 'id': id, 'result': utf8.decode(result, allowMalformed: true)});
          } catch (e) {
            mainPort.send({'type': 'response', 'id': id, 'error': e.toString()});
          }

        case 'input':
          final data = msg['data'] as String;
          shell?.write(Uint8List.fromList(utf8.encode(data)));

        case 'resize':
          final cols = msg['cols'] as int;
          final rows = msg['rows'] as int;
          shell?.resizeTerminal(cols, rows);

        case 'close':
          shell?.close();
          client?.close();
          await client?.done.catchError((_) {});
          client = null;
          shell = null;
      }
    });
  }

  static List<SSHKeyPair> _parseKey(String pem) {
    try {
      return SSHKeyPair.fromPem(pem);
    } catch (_) {
      return [];
    }
  }
}
