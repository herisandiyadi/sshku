class SnippetModel {
  final int? id;
  final int? folderId;
  final String title;
  final String command;
  final String? description;
  final int sortOrder;
  final String? createdAt;

  SnippetModel({this.id, this.folderId, required this.title, required this.command, this.description, this.sortOrder = 0, this.createdAt});

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'folder_id': folderId,
    'title': title,
    'command': command,
    'description': description,
    'sort_order': sortOrder,
    'created_at': createdAt,
  };

  factory SnippetModel.fromMap(Map<String, dynamic> map) => SnippetModel(
    id: map['id'] as int?,
    folderId: map['folder_id'] as int?,
    title: map['title'] as String,
    command: map['command'] as String,
    description: map['description'] as String?,
    sortOrder: map['sort_order'] as int? ?? 0,
    createdAt: map['created_at'] as String?,
  );
}
