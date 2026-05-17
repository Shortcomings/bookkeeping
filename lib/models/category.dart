class Category {
  final String id;
  final String name;
  final int type; // 0=expense, 1=income
  final String icon;
  final String color;
  final String? parentId;
  final bool isEnabled;
  final int sortOrder;
  final String createdAt;
  final String updatedAt;

  const Category({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
    this.parentId,
    this.isEnabled = true,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type,
        'icon': icon,
        'color': color,
        'parent_id': parentId,
        'is_enabled': isEnabled ? 1 : 0,
        'sort_order': sortOrder,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory Category.fromMap(Map<String, dynamic> map) => Category(
        id: map['id'] as String,
        name: map['name'] as String,
        type: map['type'] as int,
        icon: map['icon'] as String,
        color: map['color'] as String,
        parentId: map['parent_id'] as String?,
        isEnabled: (map['is_enabled'] as int?) != 0,
        sortOrder: (map['sort_order'] as int?) ?? 0,
        createdAt: map['created_at'] as String,
        updatedAt: map['updated_at'] as String,
      );

  Category copyWith({
    String? id,
    String? name,
    int? type,
    String? icon,
    String? color,
    String? parentId,
    bool? isEnabled,
    int? sortOrder,
    String? createdAt,
    String? updatedAt,
  }) =>
      Category(
        id: id ?? this.id,
        name: name ?? this.name,
        type: type ?? this.type,
        icon: icon ?? this.icon,
        color: color ?? this.color,
        parentId: parentId ?? this.parentId,
        isEnabled: isEnabled ?? this.isEnabled,
        sortOrder: sortOrder ?? this.sortOrder,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
