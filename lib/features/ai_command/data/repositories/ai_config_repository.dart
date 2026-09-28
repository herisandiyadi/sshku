import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/security/credential_manager.dart';

/// Konfigurasi AI Command yang dibaca UI & datasource.
class AiConfig {
  final String baseUrl;
  final String model;

  /// API key plaintext (hasil dekripsi). Kosong = tanpa auth (endpoint lokal).
  final String apiKey;

  const AiConfig({this.baseUrl = '', this.model = '', this.apiKey = ''});

  /// Fitur dianggap siap dipakai bila base URL & model terisi.
  bool get isConfigured => baseUrl.trim().isNotEmpty && model.trim().isNotEmpty;
}

/// Menyimpan base URL & model di [SharedPreferences]; API key disimpan sebagai
/// ciphertext (Android Keystore via [CredentialManager]) — plaintext tak pernah
/// ditulis ke disk.
class AiConfigRepository {
  static const _kBaseUrl = 'ai_base_url';
  static const _kModel = 'ai_model';
  static const _kApiKeyEnc = 'ai_api_key_enc';

  final CredentialManager _credentials;

  AiConfigRepository(this._credentials);

  Future<AiConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString(_kBaseUrl) ?? '';
    final model = prefs.getString(_kModel) ?? '';
    final enc = prefs.getString(_kApiKeyEnc);

    var apiKey = '';
    if (enc != null && enc.isNotEmpty) {
      try {
        apiKey = await _credentials.decryptPassword(enc);
      } catch (_) {
        apiKey = ''; // key rusak / Keystore reset -> perlakukan sebagai kosong
      }
    }
    return AiConfig(baseUrl: baseUrl, model: model, apiKey: apiKey);
  }

  Future<void> save({
    required String baseUrl,
    required String model,
    required String apiKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBaseUrl, baseUrl.trim());
    await prefs.setString(_kModel, model.trim());

    if (apiKey.trim().isEmpty) {
      await prefs.remove(_kApiKeyEnc);
    } else {
      final enc = await _credentials.encryptPassword(apiKey.trim());
      await prefs.setString(_kApiKeyEnc, enc);
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kBaseUrl);
    await prefs.remove(_kModel);
    await prefs.remove(_kApiKeyEnc);
  }
}
