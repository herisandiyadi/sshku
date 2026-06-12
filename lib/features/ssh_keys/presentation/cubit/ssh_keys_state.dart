import 'package:equatable/equatable.dart';
import 'package:sshku/features/ssh_keys/data/models/ssh_key_model.dart';

sealed class SshKeysState extends Equatable {
  const SshKeysState();
  @override
  List<Object?> get props => [];
}

class SshKeysInitial extends SshKeysState {}

class SshKeysLoading extends SshKeysState {}

class SshKeysLoaded extends SshKeysState {
  final List<SshKeyModel> keys;
  const SshKeysLoaded(this.keys);
  @override
  List<Object?> get props => [keys];
}

class SshKeysError extends SshKeysState {
  final String message;
  const SshKeysError(this.message);
  @override
  List<Object?> get props => [message];
}
