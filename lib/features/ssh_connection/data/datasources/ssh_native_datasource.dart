import 'package:sshku/core/platform/dart_ssh_service.dart';

abstract class SshNativeDatasource {
  Future<void> connect({
    required String host,
    required int port,
    required String username,
    String? password,
    String? privateKey,
  });

  Future<void> disconnect();

  Future<String> execute(String command);
}

class SshNativeDatasourceImpl implements SshNativeDatasource {
  final DartSshService _ssh = DartSshService();

  @override
  Future<void> connect({
    required String host,
    required int port,
    required String username,
    String? password,
    String? privateKey,
  }) {
    return _ssh.connect(
      host: host,
      port: port,
      username: username,
      password: password,
      privateKey: privateKey,
    );
  }

  @override
  Future<void> disconnect() async {
    await _ssh.close();
  }

  @override
  
  Future<String> execute(String command) {
    return _ssh.execute(command);
  }
}
