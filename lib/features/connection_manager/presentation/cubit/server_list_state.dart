import 'package:equatable/equatable.dart';
import 'package:sshku/features/ssh_connection/data/models/connection_model.dart';

sealed class ServerListState extends Equatable {
  const ServerListState();
  @override
  List<Object?> get props => [];
}

class ServerListInitial extends ServerListState {}

class ServerListLoading extends ServerListState {}

class ServerListLoaded extends ServerListState {
  final List<ConnectionModel> connections;
  const ServerListLoaded(this.connections);
  @override
  List<Object?> get props => [connections];
}

class ServerListError extends ServerListState {
  final String message;
  const ServerListError(this.message);
  @override
  List<Object?> get props => [message];
}
