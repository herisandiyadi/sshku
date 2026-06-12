class SnippetFolderModel {
  final int? id;
  final String name;
  final int sortOrder;
  final String? createdAt;

  SnippetFolderModel({this.id, required this.name, this.sortOrder = 0, this.createdAt});

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'sort_order': sortOrder,
    'created_at': createdAt,
  };

  factory SnippetFolderModel.fromMap(Map<String, dynamic> map) => SnippetFolderModel(
    id: map['id'] as int?,
    name: map['name'] as String,
    sortOrder: map['sort_order'] as int? ?? 0,
    createdAt: map['created_at'] as String?,
  );
}
