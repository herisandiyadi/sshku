class ConnectionModel {
  final int? id;
  final String? name;
  final String host;
  final int port;
  final String username;
  final String? authType;
  final String? createdAt;
  final int? groupId;

  ConnectionModel({
    this.id,
    this.name,
    required this.host,
    this.port = 22,
    required this.username,
    this.authType,
    this.createdAt,
    this.groupId,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'host': host,
        'port': port,
        'username': username,
        'auth_type': authType,
        'created_at': createdAt ?? DateTime.now().toIso8601String(),
        'group_id': groupId,
      };

  factory ConnectionModel.fromMap(Map<String, dynamic> map) => ConnectionModel(
        id: map['id'] as int?,
        name: map['name'] as String?,
        host: map['host'] as String,
        port: map['port'] as int? ?? 22,
        username: map['username'] as String,
        authType: map['auth_type'] as String?,
        createdAt: map['created_at'] as String?,
        groupId: map['group_id'] as int?,
      );

  ConnectionModel copyWith({int? groupId, bool clearGroup = false}) => ConnectionModel(
        id: id,
        name: name,
        host: host,
        port: port,
        username: username,
        authType: authType,
        createdAt: createdAt,
        groupId: clearGroup ? null : (groupId ?? this.groupId),
      );
}
