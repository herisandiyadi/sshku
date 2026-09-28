import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sshku/core/platform/keystore_platform_channel.dart';
import 'package:sshku/core/security/credential_manager.dart';
import 'package:sshku/features/ai_command/data/repositories/ai_config_repository.dart';

/// Fake enkripsi: prefiks sederhana, reversible — tanpa platform channel.
class FakeCredentials extends CredentialManager {
  FakeCredentials() : super(KeystorePlatformChannel());
  @override
  Future<String> encryptPassword(String password) async => 'enc:$password';
  @override
  Future<String> decryptPassword(String encrypted) async =>
      encrypted.replaceFirst('enc:', '');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AiConfigRepository repo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repo = AiConfigRepository(FakeCredentials());
  });

  test('save lalu load mengembalikan nilai yang sama (roundtrip)', () async {
    await repo.save(baseUrl: 'https://api/v1', model: 'gpt', apiKey: 'secret');
    final config = await repo.load();
    expect(config.baseUrl, 'https://api/v1');
    expect(config.model, 'gpt');
    expect(config.apiKey, 'secret');
    expect(config.isConfigured, isTrue);
  });

  test('API key disimpan sebagai ciphertext, bukan plaintext', () async {
    await repo.save(baseUrl: 'b', model: 'm', apiKey: 'rahasia');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('ai_api_key_enc'), 'enc:rahasia');
    expect(prefs.getString('ai_api_key_enc'), isNot(contains('rahasia\u0000')));
  });

  test('apiKey kosong -> entri ciphertext dihapus', () async {
    await repo.save(baseUrl: 'b', model: 'm', apiKey: 'x');
    await repo.save(baseUrl: 'b', model: 'm', apiKey: '');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('ai_api_key_enc'), isNull);
    final config = await repo.load();
    expect(config.apiKey, '');
  });

  test('isConfigured false bila base URL atau model kosong', () async {
    await repo.save(baseUrl: '', model: 'm', apiKey: '');
    expect((await repo.load()).isConfigured, isFalse);
  });

  test('clear menghapus semua', () async {
    await repo.save(baseUrl: 'b', model: 'm', apiKey: 'k');
    await repo.clear();
    final config = await repo.load();
    expect(config.baseUrl, '');
    expect(config.model, '');
    expect(config.apiKey, '');
  });
}
