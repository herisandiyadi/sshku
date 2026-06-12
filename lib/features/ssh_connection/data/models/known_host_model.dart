class KnownHostModel {
  final int? id;
  final String host;
  final int port;
  final String fingerprint;
  final String? keyType;
  final String? firstSeen;

  KnownHostModel({
    this.id,
    required this.host,
    required this.port,
    required this.fingerprint,
    this.keyType,
    this.firstSeen,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'host': host,
        'port': port,
        'fingerprint': fingerprint,
        'key_type': keyType,
        'first_seen': firstSeen ?? DateTime.now().toIso8601String(),
      };

  factory KnownHostModel.fromMap(Map<String, dynamic> map) => KnownHostModel(
        id: map['id'] as int?,
        host: map['host'] as String,
        port: map['port'] as int? ?? 22,
        fingerprint: map['fingerprint'] as String,
        keyType: map['key_type'] as String?,
        firstSeen: map['first_seen'] as String?,
      );
}
