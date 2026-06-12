import 'package:sshku/core/platform/ssh_platform_channel.dart';

abstract class SshNativeDatasource {
  Future<String> connect({
    required String host,
    required int port,
    required String username,
    String? password,
    String? privateKey,
  });

  Future<void> disconnect(String connectionId);

  Future<String> execute(String connectionId, String command);
}

class SshNativeDatasourceImpl implements SshNativeDatasource {
  final SshPlatformChannel _channel;

  SshNativeDatasourceImpl(this._channel);

  @override
  Future<String> connect({
    required String host,
    required int port,
    required String username,
    String? password,
    String? privateKey,
  }) {
    return _channel.connect(
      host: host,
      port: port,
      username: username,
      password: password,
      privateKey: privateKey,
    );
  }

  @override
  Future<void> disconnect(String connectionId) async {
    await _channel.disconnect(connectionId);
  }

  @override
  Future<String> execute(String connectionId, String command) {
    return _channel.execute(connectionId, command);
  }
}
