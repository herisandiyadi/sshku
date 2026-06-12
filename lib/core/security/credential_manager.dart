import '../platform/keystore_platform_channel.dart';

class CredentialManager {
  final KeystorePlatformChannel _keystore;

  CredentialManager(this._keystore);

  Future<String> encryptPassword(String password) => _keystore.encrypt(password);

  Future<String> decryptPassword(String encrypted) => _keystore.decrypt(encrypted);
}
