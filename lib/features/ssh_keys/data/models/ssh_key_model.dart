class SshKeyModel {
  final int? id;
  final String name;
  final String type;
  final String publicKey;
  final String encryptedPrivateKey;
  final String createdAt;

  SshKeyModel({
    this.id,
    required this.name,
    required this.type,
    required this.publicKey,
    required this.encryptedPrivateKey,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'type': type,
        'public_key': publicKey,
        'encrypted_private_key': encryptedPrivateKey,
        'created_at': createdAt,
      };

  factory SshKeyModel.fromMap(Map<String, dynamic> map) => SshKeyModel(
        id: map['id'] as int?,
        name: map['name'] as String,
        type: map['type'] as String,
        publicKey: map['public_key'] as String,
        encryptedPrivateKey: map['encrypted_private_key'] as String,
        createdAt: map['created_at'] as String,
      );
}
