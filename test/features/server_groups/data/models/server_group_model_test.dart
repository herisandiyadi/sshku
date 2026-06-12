import 'package:flutter_test/flutter_test.dart';
import 'package:sshku/features/server_groups/data/models/server_group_model.dart';

void main() {
  final model = ServerGroupModel(id: 1, name: 'Production', color: '#FF0000', sortOrder: 2);

  test('toMap/fromMap roundtrip preserves all fields', () {
    final result = ServerGroupModel.fromMap(model.toMap());
    expect(result.id, model.id);
    expect(result.name, model.name);
    expect(result.color, model.color);
    expect(result.sortOrder, model.sortOrder);
  });

  test('fromMap defaults sortOrder to 0 when missing', () {
    final result = ServerGroupModel.fromMap({'name': 'Dev', 'color': null});
    expect(result.sortOrder, 0);
  });
}
