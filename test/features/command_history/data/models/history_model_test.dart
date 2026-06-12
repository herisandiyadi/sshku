import 'package:flutter_test/flutter_test.dart';
import 'package:sshku/features/command_history/data/models/history_model.dart';

void main() {
  final model = HistoryModel(
    id: 1,
    sessionId: 'sess-123',
    command: 'ls -la',
    serverHost: '10.0.0.1',
    executedAt: '2024-06-01T12:00:00.000',
  );

  test('toMap/fromMap roundtrip preserves all fields', () {
    final result = HistoryModel.fromMap(model.toMap());
    expect(result.id, model.id);
    expect(result.sessionId, model.sessionId);
    expect(result.command, model.command);
    expect(result.serverHost, model.serverHost);
    expect(result.executedAt, model.executedAt);
  });

  test('toMap excludes id when null', () {
    final noId = HistoryModel(command: 'pwd');
    expect(noId.toMap().containsKey('id'), false);
  });
}
