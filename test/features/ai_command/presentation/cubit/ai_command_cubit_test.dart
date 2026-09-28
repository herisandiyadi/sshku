import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sshku/core/security/credential_manager.dart';
import 'package:sshku/core/platform/keystore_platform_channel.dart';
import 'package:sshku/features/ai_command/data/datasources/ai_provider_datasource.dart';
import 'package:sshku/features/ai_command/data/models/ai_command.dart';
import 'package:sshku/features/ai_command/data/repositories/ai_config_repository.dart';
import 'package:sshku/features/ai_command/presentation/cubit/ai_command_cubit.dart';
import 'package:sshku/features/ai_command/presentation/cubit/ai_command_state.dart';

class _FakeConfigRepo extends AiConfigRepository {
  final AiConfig config;
  _FakeConfigRepo(this.config) : super(_DummyCredentials());
  @override
  Future<AiConfig> load() async => config;
}

// load() di-override sehingga credentials tak pernah dipakai; override kedua
// method agar aman bila terpanggil dan tak menyentuh platform channel.
class _DummyCredentials extends CredentialManager {
  _DummyCredentials() : super(KeystorePlatformChannel());
  @override
  Future<String> encryptPassword(String password) async => password;
  @override
  Future<String> decryptPassword(String encrypted) async => encrypted;
}

class _StubDatasource extends AiProviderDatasource {
  final List<AiCommand>? result;
  final Object? error;
  _StubDatasource({this.result, this.error});

  @override
  Future<List<AiCommand>> generate({
    required String baseUrl,
    required String apiKey,
    required String model,
    required String systemPrompt,
    required String instruction,
  }) async {
    if (error != null) throw error!;
    return result!;
  }
}

void main() {
  const configured = AiConfig(baseUrl: 'https://x/v1', model: 'm', apiKey: 'k');

  blocTest<AiCommandCubit, AiCommandState>(
    'generate sukses -> AiGenerating lalu AiPreview dengan command terklasifikasi',
    build: () => AiCommandCubit(
      configRepo: _FakeConfigRepo(configured),
      datasource: _StubDatasource(
        result: const [AiCommand(cmd: 'rm -rf /'), AiCommand(cmd: 'ls')],
      ),
    ),
    act: (c) => c.generate('hapus semua'),
    expect: () => [
      isA<AiGenerating>(),
      isA<AiPreview>()
          .having((s) => s.commands.first.blocked, 'rm -rf / blocked', true)
          .having((s) => s.commands[1].blocked, 'ls not blocked', false),
    ],
  );

  blocTest<AiCommandCubit, AiCommandState>(
    'belum dikonfigurasi -> AiError',
    build: () => AiCommandCubit(
      configRepo: _FakeConfigRepo(const AiConfig()),
      datasource: _StubDatasource(result: const []),
    ),
    act: (c) => c.generate('apa saja'),
    expect: () => [isA<AiGenerating>(), isA<AiError>()],
  );

  blocTest<AiCommandCubit, AiCommandState>(
    'datasource melempar -> AiError',
    build: () => AiCommandCubit(
      configRepo: _FakeConfigRepo(configured),
      datasource: _StubDatasource(error: Exception('boom')),
    ),
    act: (c) => c.generate('sesuatu'),
    expect: () => [
      isA<AiGenerating>(),
      isA<AiError>().having((s) => s.message, 'pesan', contains('boom')),
    ],
  );

  blocTest<AiCommandCubit, AiCommandState>(
    'instruksi kosong -> tidak ada emisi',
    build: () => AiCommandCubit(
      configRepo: _FakeConfigRepo(configured),
      datasource: _StubDatasource(result: const []),
    ),
    act: (c) => c.generate('   '),
    expect: () => const <AiCommandState>[],
  );
}
