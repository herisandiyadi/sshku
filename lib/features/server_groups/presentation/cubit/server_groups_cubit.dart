import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sshku/core/database/database_helper.dart';
import 'package:sshku/features/server_groups/data/models/server_group_model.dart';
import 'server_groups_state.dart';

class ServerGroupsCubit extends Cubit<ServerGroupsState> {
  ServerGroupsCubit() : super(ServerGroupsInitial());

  Future<void> loadGroups() async {
    final groups = await DatabaseHelper.instance.getGroups();
    emit(ServerGroupsLoaded(groups));
  }

  Future<void> addGroup(ServerGroupModel group) async {
    await DatabaseHelper.instance.insertGroup(group);
    await loadGroups();
  }

  Future<void> updateGroup(ServerGroupModel group) async {
    await DatabaseHelper.instance.updateGroup(group);
    await loadGroups();
  }

  Future<void> deleteGroup(int id) async {
    await DatabaseHelper.instance.deleteGroup(id);
    await loadGroups();
  }
}
