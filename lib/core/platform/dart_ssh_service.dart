import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

class DartSshService {
  Isolate? _isolate;
  SendPort? _cmdPort;
  final _outputController = StreamController<String>.broadcast();
  Completer<void>? _connectCompleter;
  Completer<void>? _shellCompleter;
  Completer<Map<String, String>>? _fingerprintCompleter;
  Completer<String>? _executeCompleter;

  Stream<String> get outputStream => _outputController.stream;

  Future<Map<String, String>> getHostFingerprintMap({
    required String host,
    required int port,
  }) async {
    await _ensureIsolate();
    _fingerprintCompleter = Completer<Map<String, String>>();
    _cmdPort!.send({'cmd': 'fingerprint', 'host': host, 'port': port});
    return _fingerprintCompleter!.future;
  }

  Future<void> connect({
    required String host,
    required int port,
    required String username,
    String? password,
    String? privateKey,
  }) async {
    await _ensureIsolate();
    _connectCompleter = Completer<void>();
    _cmdPort!.send({
      'cmd': 'connect',
      'host': host,
      'port': port,
      'username': username,
      'password': password,
      'privateKey': privateKey,
    });
    return _connectCompleter!.future;
  }

  Future<void> openShell({int cols = 80, int rows = 24}) async {
    _shellCompleter = Completer<void>();
    _cmdPort!.send({'cmd': 'openShell', 'cols': cols, 'rows': rows});
    return _shellCompleter!.future;
  }

  void sendInput(String input) {
    _cmdPort?.send({'cmd': 'input', 'data': input});
  }

  Future<String> execute(String command) async {
    await _ensureIsolate();
    _executeCompleter = Completer<String>();
    _cmdPort!.send({'cmd': 'execute', 'command': command});
    return _executeCompleter!.future;
  }

  void resize(int cols, int rows) {
    _cmdPort?.send({'cmd': 'resize', 'cols': cols, 'rows': rows});
  }

  Future<void> close() async {
    _cmdPort?.send({'cmd': 'close'});
    await Future.delayed(const Duration(milliseconds: 100));
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _cmdPort = null;
  }

  void dispose() {
    close();
    if (!_outputController.isClosed) _outputController.close();
  }

  Future<void> _ensureIsolate() async {
    if (_isolate != null) return;

    final receivePort = ReceivePort();
    _isolate = await Isolate.spawn(_isolateEntry, receivePort.sendPort);

    final completer = Completer<SendPort>();
    receivePort.listen((message) {
      if (message is SendPort) {
        completer.complete(message);
      } else if (message is Map) {
        _handleEvent(message);
      }
    });

    _cmdPort = await completer.future;
  }

  void _handleEvent(Map message) {
    final type = message['type'] as String;
    switch (type) {
      case 'output':
        if (!_outputController.isClosed) {
          _outputController.add(message['data'] as String);
        }
      case 'connected':
        _connectCompleter?.complete();
        _connectCompleter = null;
      case 'shellOpened':
        _shellCompleter?.complete();
        _shellCompleter = null;
      case 'error':
        final err = Exception(message['message'] as String);
        if (_fingerprintCompleter != null && !_fingerprintCompleter!.isCompleted) {
          _fingerprintCompleter!.completeError(err);
          _fingerprintCompleter = null;
        } else if (_connectCompleter != null && !_connectCompleter!.isCompleted) {
          _connectCompleter!.completeError(err);
          _connectCompleter = null;
        } else if (_shellCompleter != null && !_shellCompleter!.isCompleted) {
          _shellCompleter!.completeError(err);
          _shellCompleter = null;
        } else if (_executeCompleter != null && !_executeCompleter!.isCompleted) {
          _executeCompleter!.completeError(err);
          _executeCompleter = null;
        }
      case 'done':
        if (!_outputController.isClosed) _outputController.close();
      case 'fingerprint':
        _fingerprintCompleter?.complete({
          'fingerprint': message['fingerprint'] as String,
          'keyType': message['keyType'] as String,
        });
        _fingerprintCompleter = null;
      case 'executeResult':
        _executeCompleter?.complete(message['output'] as String);
        _executeCompleter = null;
    }
  }

  static void _isolateEntry(SendPort mainPort) {
    final cmdPort = ReceivePort();
    mainPort.send(cmdPort.sendPort);

    SSHClient? client;
    SSHSession? shell;

    cmdPort.listen((message) async {
      if (message is! Map) return;
      final cmd = message['cmd'] as String;

      switch (cmd) {
        case 'fingerprint':
          try {
            final host = message['host'] as String;
            final port = message['port'] as int;
            String? fingerprint;
            String? keyType;
            final socket = await SSHSocket.connect(host, port,
                timeout: const Duration(seconds: 5));
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
              await probe.authenticated.timeout(const Duration(seconds: 5));
            } catch (_) {}
            probe.close();
            await probe.done.catchError((_) {});
            if (fingerprint == null) {
              mainPort.send({'type': 'error', 'message': 'Could not retrieve host key'});
            } else {
              mainPort.send({'type': 'fingerprint', 'fingerprint': fingerprint!, 'keyType': keyType ?? 'unknown'});
            }
          } catch (e) {
            mainPort.send({'type': 'error', 'message': e.toString()});
          }

        case 'connect':
          try {
            final host = message['host'] as String;
            final port = message['port'] as int;
            final username = message['username'] as String;
            final password = message['password'] as String?;
            final privateKey = message['privateKey'] as String?;
            final socket = await SSHSocket.connect(host, port,
                timeout: const Duration(seconds: 5));
            client = SSHClient(
              socket,
              username: username,
              onVerifyHostKey: (_, __) => true,
              onPasswordRequest: password != null ? () => password : null,
              identities: privateKey != null ? _parseKey(privateKey) : null,
            );
            await client!.authenticated;
            mainPort.send({'type': 'connected'});
          } catch (e) {
            mainPort.send({'type': 'error', 'message': e.toString()});
          }

        case 'openShell':
          try {
            final cols = message['cols'] as int;
            final rows = message['rows'] as int;
            shell = await client!.shell(
              pty: SSHPtyConfig(type: 'xterm-256color', width: cols, height: rows),
            );
            mainPort.send({'type': 'shellOpened'});
            shell!.stdout.listen(
              (data) => mainPort.send({'type': 'output', 'data': utf8.decode(data, allowMalformed: true)}),
              onDone: () => mainPort.send({'type': 'done'}),
            );
            shell!.stderr.listen(
              (data) => mainPort.send({'type': 'output', 'data': utf8.decode(data, allowMalformed: true)}),
            );
          } catch (e) {
            mainPort.send({'type': 'error', 'message': e.toString()});
          }

        case 'input':
          final data = message['data'] as String;
          shell?.stdin.add(Uint8List.fromList(utf8.encode(data)));

        case 'execute':
          try {
            final command = message['command'] as String;
            final result = await client!.run(command);
            mainPort.send({'type': 'executeResult', 'output': utf8.decode(result, allowMalformed: true)});
          } catch (e) {
            mainPort.send({'type': 'error', 'message': e.toString()});
          }

        case 'resize':
          final cols = message['cols'] as int;
          final rows = message['rows'] as int;
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
