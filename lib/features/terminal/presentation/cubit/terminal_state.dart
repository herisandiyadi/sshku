import 'package:equatable/equatable.dart';

import '../../domain/terminal_buffer.dart';

sealed class TerminalState extends Equatable {
  const TerminalState();
  @override
  List<Object?> get props => [];
}

class TerminalIdle extends TerminalState {}

class TerminalConnecting extends TerminalState {}

class TerminalHostKeyPrompt extends TerminalState {
  final String host;
  final int port;
  final String fingerprint;
  final String? keyType;
  final bool isChanged;

  const TerminalHostKeyPrompt({
    required this.host,
    required this.port,
    required this.fingerprint,
    this.keyType,
    required this.isChanged,
  });

  @override
  List<Object?> get props => [host, port, fingerprint, isChanged];
}

class TerminalActive extends TerminalState {
  final TerminalBuffer buffer;
  final int tick;

  const TerminalActive(this.buffer, this.tick);
  @override
  List<Object?> get props => [tick];
}

class TerminalReconnecting extends TerminalState {
  final int attempt;
  final int maxAttempts;
  const TerminalReconnecting({required this.attempt, this.maxAttempts = 3});
  @override
  List<Object?> get props => [attempt, maxAttempts];
}

class TerminalDisconnected extends TerminalState {}

class TerminalError extends TerminalState {
  final String message;
  const TerminalError(this.message);
  @override
  List<Object?> get props => [message];
}
