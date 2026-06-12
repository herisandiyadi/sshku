import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sshku/core/database/database_helper.dart';
import 'server_list_state.dart';

class ServerListCubit extends Cubit<ServerListState> {
  ServerListCubit() : super(ServerListInitial());

  Future<void> loadServers() async {
    emit(ServerListLoading());
    try {
      final connections = await DatabaseHelper.instance.getConnections();
      emit(ServerListLoaded(connections));
    } catch (e) {
      emit(ServerListError(e.toString()));
    }
  }

  Future<void> deleteServer(int id) async {
    try {
      await DatabaseHelper.instance.deleteConnection(id);
      await loadServers();
    } catch (e) {
      emit(ServerListError(e.toString()));
    }
  }
}
