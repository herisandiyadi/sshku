class ServerGroupModel {
  final int? id;
  final String name;
  final String? color;
  final int sortOrder;

  ServerGroupModel({this.id, required this.name, this.color, this.sortOrder = 0});

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'color': color,
        'sort_order': sortOrder,
      };

  factory ServerGroupModel.fromMap(Map<String, dynamic> map) => ServerGroupModel(
        id: map['id'] as int?,
        name: map['name'] as String,
        color: map['color'] as String?,
        sortOrder: map['sort_order'] as int? ?? 0,
      );
}
