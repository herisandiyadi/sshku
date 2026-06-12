import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sshku/core/database/database_helper.dart';
import 'package:sshku/features/ssh_keys/data/datasources/ssh_key_datasource.dart';
import 'package:sshku/core/platform/keystore_platform_channel.dart';
import 'ssh_keys_state.dart';

class SshKeysCubit extends Cubit<SshKeysState> {
  SshKeysCubit() : super(SshKeysInitial());

  final _datasource = SshKeyDatasource(KeystorePlatformChannel());

  Future<void> loadKeys() async {
    emit(SshKeysLoading());
    try {
      final keys = await DatabaseHelper.instance.getKeys();
      emit(SshKeysLoaded(keys));
    } catch (e) {
      emit(SshKeysError(e.toString()));
    }
  }

  Future<void> generateKey(String name, String type) async {
    try {
      final key = await _datasource.generateKey(name: name, type: type);
      await DatabaseHelper.instance.insertKey(key);
      await loadKeys();
    } catch (_) {}
  }

  Future<void> deleteKey(int id) async {
    try {
      await DatabaseHelper.instance.deleteKey(id);
      await loadKeys();
    } catch (_) {}
  }
}
