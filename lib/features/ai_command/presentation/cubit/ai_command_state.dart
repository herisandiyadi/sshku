import 'package:equatable/equatable.dart';

import '../../data/models/ai_command.dart';

sealed class AiCommandState extends Equatable {
  const AiCommandState();
  @override
  List<Object?> get props => [];
}

class AiIdle extends AiCommandState {
  const AiIdle();
}

class AiGenerating extends AiCommandState {
  const AiGenerating();
}

/// Ada hasil, menunggu approval. [commands] sudah diklasifikasi safety.
class AiPreview extends AiCommandState {
  final List<AiCommand> commands;
  const AiPreview(this.commands);
  @override
  List<Object?> get props => [commands];
}

class AiError extends AiCommandState {
  final String message;
  const AiError(this.message);
  @override
  List<Object?> get props => [message];
}
