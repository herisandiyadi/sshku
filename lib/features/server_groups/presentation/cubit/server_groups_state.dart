import 'package:equatable/equatable.dart';
import 'package:sshku/features/server_groups/data/models/server_group_model.dart';

sealed class ServerGroupsState extends Equatable {
  const ServerGroupsState();
  @override
  List<Object?> get props => [];
}

class ServerGroupsInitial extends ServerGroupsState {}

class ServerGroupsLoaded extends ServerGroupsState {
  final List<ServerGroupModel> groups;
  const ServerGroupsLoaded(this.groups);
  @override
  List<Object?> get props => [groups];
}
