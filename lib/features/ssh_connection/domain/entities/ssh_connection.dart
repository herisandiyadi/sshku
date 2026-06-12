import 'package:equatable/equatable.dart';

class SshConnection extends Equatable {
  final String id;
  final String host;
  final int port;
  final String username;

  const SshConnection({
    required this.id,
    required this.host,
    required this.port,
    required this.username,
  });

  @override
  List<Object> get props => [id, host, port, username];
}
