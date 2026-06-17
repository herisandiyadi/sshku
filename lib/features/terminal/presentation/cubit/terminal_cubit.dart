import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/platform/dart_ssh_service.dart';
import '../../../command_history/data/models/history_model.dart';
import '../../../ssh_connection/data/models/known_host_model.dart';
import '../../domain/terminal_buffer.dart';
import 'terminal_state.dart';

class TerminalCubit extends Cubit<TerminalState> {
  final DartSshService _ssh = DartSshService();
  final TerminalBuffer _buffer = TerminalBuffer();

  String? _host;
  int? _port;
  String? _username;
  String? _password;
  String? _privateKey;
  StreamSubscription<String>? _outputSub;
  int _tick = 0;
  bool _manualClose = false;
  String _currentLine = '';

  // Batching: accumulate data, process in scheduled frame
  final StringBuffer _pendingData = StringBuffer();
  bool _frameScheduled = false;

  static const int _maxRetries = 3;

  TerminalCubit() : super(TerminalIdle());

  Future<void> connectAndOpenShell(
    String host,
    int port,
    String username, {
    String? password,
    String? privateKey,
  }) async {
    _host = host;
    _port = port;
    _username = username;
    _password = password;
    _privateKey = privateKey;
    emit(TerminalConnecting());
    try {
      final knownHost = await DatabaseHelper.instance.getKnownHost(host, port);
      if (knownHost != null) {
        await _doConnect();
        return;
      }

      final hostKeyInfo = await _ssh.getHostFingerprintMap(host: host, port: port);
      final fingerprint = hostKeyInfo['fingerprint']!;
      final keyType = hostKeyInfo['keyType'];

      emit(TerminalHostKeyPrompt(
        host: host,
        port: port,
        fingerprint: fingerprint,
        keyType: keyType,
        isChanged: false,
      ));
    } catch (e) {
      emit(TerminalError(e.toString()));
    }
  }

  Future<void> acceptHostKeyAndConnect({
    required String fingerprint,
    String? keyType,
    bool isChanged = false,
  }) async {
    emit(TerminalConnecting());
    try {
      final existing = await DatabaseHelper.instance.getKnownHost(_host!, _port!);
      if (existing != null && isChanged) {
        await DatabaseHelper.instance.updateKnownHost(KnownHostModel(
          id: existing.id,
          host: _host!,
          port: _port!,
          fingerprint: fingerprint,
          keyType: keyType,
          firstSeen: existing.firstSeen,
        ));
      } else if (existing == null) {
        await DatabaseHelper.instance.insertKnownHost(KnownHostModel(
          host: _host!,
          port: _port!,
          fingerprint: fingerprint,
          keyType: keyType,
        ));
      }
      await _doConnect();
    } catch (e) {
      emit(TerminalError(e.toString()));
    }
  }

  Future<void> _doConnect() async {
    debugPrint('[TERMINAL] _doConnect start');
    await _ssh.connect(
      host: _host!,
      port: _port!,
      username: _username!,
      password: _password,
      privateKey: _privateKey,
    );
    debugPrint('[TERMINAL] connect done, opening shell...');
    await _ssh.openShell();
    debugPrint('[TERMINAL] shell opened, listening output...');
    _listenOutput();
    emit(TerminalActive(_buffer, _tick));
    debugPrint('[TERMINAL] TerminalActive emitted');
  }

  void _listenOutput() {
    _outputSub = _ssh.outputStream.listen(
      (data) {
        debugPrint('[TERMINAL] received ${data.length} chars from isolate');
        _pendingData.write(data);
        _scheduleFrame();
      },
      onError: (e) {
        debugPrint('[TERMINAL] stream error: $e');
        _onDisconnect();
      },
      onDone: () {
        debugPrint('[TERMINAL] stream done');
        _onDisconnect();
      },
    );
  }

  void _scheduleFrame() {
    if (_frameScheduled) return;
    _frameScheduled = true;
    Timer.run(_flushPending);
  }

  void _flushPending() {
    _frameScheduled = false;
    if (isClosed || _pendingData.isEmpty) return;
    final data = _pendingData.toString();
    _pendingData.clear();
    final sw = Stopwatch()..start();
    _buffer.write(data);
    final ms = sw.elapsedMilliseconds;
    if (ms > 5) debugPrint('[TERMINAL] buffer.write took ${ms}ms for ${data.length} chars');
    emit(TerminalActive(_buffer, _tick++));
  }

  void _onDisconnect() {
    if (_manualClose || isClosed) return;
    _autoReconnect();
  }

  Future<void> _autoReconnect() async {
    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      if (isClosed) return;
      emit(TerminalReconnecting(attempt: attempt, maxAttempts: _maxRetries));
      await Future.delayed(Duration(seconds: 1 << attempt));
      if (isClosed) return;
      try {
        await _outputSub?.cancel();
        await _ssh.close();
        await _doConnect();
        return;
      } catch (_) {}
    }
    if (!isClosed) emit(TerminalDisconnected());
  }

  Future<void> manualReconnect() async {
    if (_host == null) return;
    _autoReconnect();
  }

  void resize(int cols, int rows) {
    _buffer.resize(rows, cols);
    _ssh.resize(cols, rows);
  }

  void sendInput(String input) {
    _ssh.sendInput(input);
    // Only log commands on Enter, not every keystroke
    if (input == '\r' || input == '\n') {
      if (_currentLine.trim().isNotEmpty) {
        DatabaseHelper.instance.insertHistory(HistoryModel(
          sessionId: _host,
          command: _currentLine.trim(),
          serverHost: _host,
          executedAt: DateTime.now().toIso8601String(),
        ));
      }
      _currentLine = '';
    } else if (input.codeUnitAt(0) >= 32) {
      _currentLine += input;
    }
  }

  @override
  Future<void> close() async {
    _manualClose = true;
    _frameScheduled = false;
    await _outputSub?.cancel();
    _ssh.dispose();
    return super.close();
  }
}
