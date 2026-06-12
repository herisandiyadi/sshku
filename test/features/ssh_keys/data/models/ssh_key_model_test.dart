import 'package:flutter_test/flutter_test.dart';
import 'package:sshku/features/ssh_keys/data/models/ssh_key_model.dart';

void main() {
  final model = SshKeyModel(
    id: 1,
    name: 'my-key',
    type: 'ed25519',
    publicKey: 'ssh-ed25519 AAAAC3...',
    encryptedPrivateKey: 'encrypted-data',
    createdAt: '2024-06-01T00:00:00.000',
  );

  test('toMap/fromMap roundtrip preserves all fields', () {
    final result = SshKeyModel.fromMap(model.toMap());
    expect(result.id, model.id);
    expect(result.name, model.name);
    expect(result.type, model.type);
    expect(result.publicKey, model.publicKey);
    expect(result.encryptedPrivateKey, model.encryptedPrivateKey);
    expect(result.createdAt, model.createdAt);
  });

  test('toMap excludes id when null', () {
    final noId = SshKeyModel(
      name: 'k',
      type: 'rsa',
      publicKey: 'pub',
      encryptedPrivateKey: 'priv',
      createdAt: '2024-01-01',
    );
    expect(noId.toMap().containsKey('id'), false);
  });
}
