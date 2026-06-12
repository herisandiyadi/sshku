import 'package:flutter_test/flutter_test.dart';
import 'package:sshku/features/ssh_connection/data/models/known_host_model.dart';

void main() {
  final model = KnownHostModel(
    id: 1,
    host: '192.168.1.1',
    port: 2222,
    fingerprint: 'SHA256:abc123def456',
    keyType: 'ed25519',
    firstSeen: '2024-01-01T00:00:00.000',
  );

  test('toMap/fromMap roundtrip preserves all fields', () {
    final result = KnownHostModel.fromMap(model.toMap());
    expect(result.id, model.id);
    expect(result.host, model.host);
    expect(result.port, model.port);
    expect(result.fingerprint, model.fingerprint);
    expect(result.keyType, model.keyType);
    expect(result.firstSeen, model.firstSeen);
  });

  test('fromMap defaults port to 22 when null', () {
    final result = KnownHostModel.fromMap({
      'host': 'example.com',
      'fingerprint': 'fp',
    });
    expect(result.port, 22);
  });
}
