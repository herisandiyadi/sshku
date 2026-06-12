import 'dart:async';

import 'package:flutter/services.dart';

class SshPlatformChannel {
  static const _channel = MethodChannel('com.example.sshku/ssh');

  final _keepAliveExpiredController = StreamController<void>.broadcast();
  Stream<void> get keepAliveExpiredStream => _keepAliveExpiredController.stream;

  SshPlatformChannel() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'keepAliveExpired') {
        _keepAliveExpiredController.add(null);
      }
    });
  }

  Future<String> connect({
    required String host,
    required int port,
    required String username,
    String? password,
    String? privateKey,
    bool acceptHostKey = false,
  }) async {
    final result = await _channel.invokeMethod<String>('connect', {
      'host': host,
      'port': port,
      'username': username,
      if (password != null) 'password': password,
      if (privateKey != null) 'privateKey': privateKey,
      'acceptHostKey': acceptHostKey,
    });
    return result!;
  }

  Future<Map<String, String>> getHostFingerprint({
    required String host,
    required int port,
  }) async {
    final result = await _channel.invokeMapMethod<String, String>('getHostFingerprint', {
      'host': host,
      'port': port,
    });
    return result!;
  }

  Future<bool> disconnect(String sessionId) async {
    final result = await _channel.invokeMethod<bool>('disconnect', {
      'sessionId': sessionId,
    });
    return result!;
  }

  Future<String> execute(String sessionId, String command) async {
    final result = await _channel.invokeMethod<String>('execute', {
      'sessionId': sessionId,
      'command': command,
    });
    return result!;
  }

  Future<void> startKeepAlive({int duration = 15}) async {
    await _channel.invokeMethod('startKeepAlive', {'duration': duration});
  }

  Future<void> stopKeepAlive() async {
    await _channel.invokeMethod('stopKeepAlive');
  }

  Future<void> openShell(String sessionId) async {
    await _channel.invokeMethod('openShell', {'sessionId': sessionId});
  }

  Future<void> sendInput(String sessionId, String input) async {
    await _channel.invokeMethod('sendInput', {'sessionId': sessionId, 'input': input});
  }

  Future<void> resizeShell(String sessionId, int cols, int rows) async {
    await _channel.invokeMethod('resizeShell', {'sessionId': sessionId, 'cols': cols, 'rows': rows});
  }

  Future<void> closeShell(String sessionId) async {
    await _channel.invokeMethod('closeShell', {'sessionId': sessionId});
  }

  void dispose() {
    _keepAliveExpiredController.close();
  }
}
