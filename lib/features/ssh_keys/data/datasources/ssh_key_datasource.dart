import 'package:sshku/core/platform/keystore_platform_channel.dart';
import 'package:sshku/features/ssh_keys/data/models/ssh_key_model.dart';

class SshKeyDatasource {
  final KeystorePlatformChannel _channel;

  SshKeyDatasource(this._channel);

  Future<SshKeyModel> generateKey({
    required String name,
    required String type,
    int? bits,
    String comment = '',
  }) async {
    final result = await _channel.generateKey(
      type: type,
      bits: bits,
      comment: comment,
    );
    return SshKeyModel(
      name: name,
      type: type,
      publicKey: result['publicKey']!,
      encryptedPrivateKey: result['encryptedPrivateKey']!,
      createdAt: DateTime.now().toIso8601String(),
    );
  }
}
