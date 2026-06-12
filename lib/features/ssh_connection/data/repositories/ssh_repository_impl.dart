import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/ssh_connection.dart';
import '../../domain/repositories/ssh_repository.dart';
import '../datasources/ssh_native_datasource.dart';

class SshRepositoryImpl implements SshRepository {
  final SshNativeDatasource datasource;

  SshRepositoryImpl(this.datasource);

  @override
  Future<Either<Failure, SshConnection>> connect({
    required String host,
    required int port,
    required String username,
    String? password,
    String? privateKey,
  }) async {
    try {
      final id = await datasource.connect(
        host: host,
        port: port,
        username: username,
        password: password,
        privateKey: privateKey,
      );
      return Right(SshConnection(id: id, host: host, port: port, username: username));
    } catch (e) {
      return Left(ConnectionFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> disconnect(String connectionId) async {
    try {
      await datasource.disconnect(connectionId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> execute(String connectionId, String command) async {
    try {
      final output = await datasource.execute(connectionId, command);
      return Right(output);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
