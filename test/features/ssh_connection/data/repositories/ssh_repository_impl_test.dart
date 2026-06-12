import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sshku/core/error/failures.dart';
import 'package:sshku/features/ssh_connection/data/datasources/ssh_native_datasource.dart';
import 'package:sshku/features/ssh_connection/data/repositories/ssh_repository_impl.dart';
import 'package:sshku/features/ssh_connection/domain/entities/ssh_connection.dart';

class MockSshNativeDatasource implements SshNativeDatasource {
  String? connectResult;
  String? executeResult;
  Exception? error;

  @override
  Future<String> connect({required String host, required int port, required String username, String? password, String? privateKey}) async {
    if (error != null) throw error!;
    return connectResult!;
  }

  @override
  Future<void> disconnect(String connectionId) async {
    if (error != null) throw error!;
  }

  @override
  Future<String> execute(String connectionId, String command) async {
    if (error != null) throw error!;
    return executeResult!;
  }
}

void main() {
  late MockSshNativeDatasource mockDatasource;
  late SshRepositoryImpl repository;

  setUp(() {
    mockDatasource = MockSshNativeDatasource();
    repository = SshRepositoryImpl(mockDatasource);
  });

  group('connect', () {
    test('success returns Right(SshConnection)', () async {
      mockDatasource.connectResult = 'conn-1';
      final result = await repository.connect(host: '10.0.0.1', port: 22, username: 'root');
      expect(result, Right(const SshConnection(id: 'conn-1', host: '10.0.0.1', port: 22, username: 'root')));
    });

    test('failure returns Left(ConnectionFailure)', () async {
      mockDatasource.error = Exception('timeout');
      final result = await repository.connect(host: '10.0.0.1', port: 22, username: 'root');
      expect(result.isLeft(), true);
      result.fold((f) => expect(f, isA<ConnectionFailure>()), (_) => fail('expected Left'));
    });
  });

  group('disconnect', () {
    test('success returns Right(null)', () async {
      final result = await repository.disconnect('conn-1');
      expect(result, const Right(null));
    });
  });

  group('execute', () {
    test('success returns Right(output)', () async {
      mockDatasource.executeResult = 'hello';
      final result = await repository.execute('conn-1', 'echo hello');
      expect(result, const Right('hello'));
    });

    test('failure returns Left(ServerFailure)', () async {
      mockDatasource.error = Exception('closed');
      final result = await repository.execute('conn-1', 'ls');
      expect(result.isLeft(), true);
      result.fold((f) => expect(f, isA<ServerFailure>()), (_) => fail('expected Left'));
    });
  });
}
