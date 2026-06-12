import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/platform/shell_event_channel.dart';
import '../../../../core/platform/ssh_platform_channel.dart';
import '../../../command_history/data/models/history_model.dart';
import '../../../ssh_connection/data/models/known_host_model.dart';
import '../../domain/terminal_buffer.dart';
import 'terminal_state.dart';

class TerminalCubit extends Cubit<TerminalState> {
  final SshPlatformChannel _sshChannel;
  final ShellEventChannel _shellEventChannel;
  final TerminalBuffer _buffer = TerminalBuffer();

  SshPlatformChannel get sshChannel => _sshChannel;

  String? _sessionId;
  String? _host;
  int? _port;
  String? _username;
  String? _password;
  String? _privateKey;
  StreamSubscription<String>? _outputSub;
  Timer? _debounce;
  int _tick = 0;
  bool _manualClose = false;

  static const int _maxRetries = 3;

  TerminalCubit({
    SshPlatformChannel? sshChannel,
    ShellEventChannel? shellEventChannel,
  })  : _sshChannel = sshChannel ?? SshPlatformChannel(),
        _shellEventChannel = shellEventChannel ?? ShellEventChannel(),
        super(TerminalIdle());

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
      // Host key verification
      final knownHost = await DatabaseHelper.instance.getKnownHost(host, port);
      final hostKeyInfo = await _sshChannel.getHostFingerprint(host: host, port: port);
      final fingerprint = hostKeyInfo['fingerprint']!;
      final keyType = hostKeyInfo['keyType'];

      if (knownHost == null) {
        emit(TerminalHostKeyPrompt(
          host: host,
          port: port,
          fingerprint: fingerprint,
          keyType: keyType,
          isChanged: false,
        ));
        return;
      } else if (knownHost.fingerprint != fingerprint) {
        emit(TerminalHostKeyPrompt(
          host: host,
          port: port,
          fingerprint: fingerprint,
          keyType: keyType,
          isChanged: true,
        ));
        return;
      }

      // Known and matches - connect silently
      await _doConnect();
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
    _sessionId = await _sshChannel.connect(
      host: _host!,
      port: _port!,
      username: _username!,
      password: _password,
      privateKey: _privateKey,
      acceptHostKey: true,
    );
    await _sshChannel.openShell(_sessionId!);
    _listenOutput();
    emit(TerminalActive(_buffer, _tick));
  }

  void _listenOutput() {
    _outputSub = _shellEventChannel.outputStream.listen(
      (data) {
        _buffer.write(data);
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 16), () {
          if (!isClosed) {
            emit(TerminalActive(_buffer, _tick++));
          }
        });
      },
      onError: (_) => _onDisconnect(),
      onDone: () => _onDisconnect(),
    );
  }

  void _onDisconnect() {
    if (_manualClose || isClosed) return;
    _autoReconnect();
  }

  Future<void> _autoReconnect() async {
    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      if (isClosed) return;
      emit(TerminalReconnecting(attempt: attempt, maxAttempts: _maxRetries));
      final delay = Duration(seconds: 1 << attempt);
      await Future.delayed(delay);
      if (isClosed) return;
      try {
        await _outputSub?.cancel();
        if (_sessionId != null) {
          try {
            await _sshChannel.closeShell(_sessionId!);
          } catch (_) {}
        }
        await _doConnect();
        return;
      } catch (_) {
        // continue to next attempt
      }
    }
    if (!isClosed) emit(TerminalDisconnected());
  }

  Future<void> manualReconnect() async {
    if (_host == null) return;
    _autoReconnect();
  }

  Future<void> resize(int cols, int rows) async {
    _buffer.resize(rows, cols);
    if (_sessionId != null) {
      await _sshChannel.resizeShell(_sessionId!, cols, rows);
    }
    if (state is TerminalActive) {
      _tick++;
      emit(TerminalActive(_buffer, _tick));
    }
  }

  Future<void> sendInput(String input) async {
    if (_sessionId == null) return;
    await _sshChannel.sendInput(_sessionId!, input);
    if (input.trim().isNotEmpty) {
      DatabaseHelper.instance.insertHistory(HistoryModel(
        sessionId: _sessionId,
        command: input.trim(),
        serverHost: _host,
        executedAt: DateTime.now().toIso8601String(),
      ));
    }
  }

  @override
  Future<void> close() async {
    _manualClose = true;
    _debounce?.cancel();
    await _outputSub?.cancel();
    if (_sessionId != null) {
      await _sshChannel.closeShell(_sessionId!);
    }
    _sshChannel.dispose();
    return super.close();
  }
}
