import 'package:flutter_test/flutter_test.dart';
import 'package:sshku/features/ssh_connection/data/models/connection_model.dart';

void main() {
  final model = ConnectionModel(id: 1, name: 'srv', host: '10.0.0.1', port: 22, username: 'root', authType: 'password', createdAt: '2024-01-01T00:00:00.000');

  test('toMap() produces correct keys', () {
    final map = model.toMap();
    expect(map['id'], 1);
    expect(map['host'], '10.0.0.1');
    expect(map['port'], 22);
    expect(map['username'], 'root');
    expect(map['auth_type'], 'password');
    expect(map['created_at'], '2024-01-01T00:00:00.000');
  });

  test('fromMap() creates correct model', () {
    final map = {'id': 1, 'name': 'srv', 'host': '10.0.0.1', 'port': 22, 'username': 'root', 'auth_type': 'password', 'created_at': '2024-01-01T00:00:00.000'};
    final result = ConnectionModel.fromMap(map);
    expect(result.id, 1);
    expect(result.host, '10.0.0.1');
    expect(result.port, 22);
    expect(result.username, 'root');
    expect(result.authType, 'password');
  });

  test('roundtrip fromMap(toMap()) preserves data', () {
    final roundtrip = ConnectionModel.fromMap(model.toMap());
    expect(roundtrip.id, model.id);
    expect(roundtrip.host, model.host);
    expect(roundtrip.port, model.port);
    expect(roundtrip.username, model.username);
    expect(roundtrip.authType, model.authType);
  });
}
