class HistoryModel {
  final int? id;
  final String? sessionId;
  final String command;
  final String? serverHost;
  final String? executedAt;

  HistoryModel({
    this.id,
    this.sessionId,
    required this.command,
    this.serverHost,
    this.executedAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'session_id': sessionId,
        'command': command,
        'server_host': serverHost,
        'executed_at': executedAt,
      };

  factory HistoryModel.fromMap(Map<String, dynamic> map) => HistoryModel(
        id: map['id'] as int?,
        sessionId: map['session_id'] as String?,
        command: map['command'] as String,
        serverHost: map['server_host'] as String?,
        executedAt: map['executed_at'] as String?,
      );
}
