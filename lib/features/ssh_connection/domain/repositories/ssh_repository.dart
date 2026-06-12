import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/ssh_connection.dart';

abstract class SshRepository {
  Future<Either<Failure, SshConnection>> connect({
    required String host,
    required int port,
    required String username,
    String? password,
    String? privateKey,
  });

  Future<Either<Failure, void>> disconnect(String connectionId);

  Future<Either<Failure, String>> execute(String connectionId, String command);
}
