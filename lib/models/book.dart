class Book {
  final String id;
  final String name;
  final String icon;
  final String color;
  final int type; // 0=personal, 1=shared
  final bool isShared;
  final String createdAt;
  final String updatedAt;

  const Book({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.type = 0,
    this.isShared = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'icon': icon,
        'color': color,
        'type': type,
        'is_shared': isShared ? 1 : 0,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory Book.fromMap(Map<String, dynamic> map) => Book(
        id: map['id'] as String,
        name: map['name'] as String,
        icon: map['icon'] as String,
        color: map['color'] as String,
        type: (map['type'] as int?) ?? 0,
        isShared: (map['is_shared'] as int?) == 1,
        createdAt: map['created_at'] as String,
        updatedAt: map['updated_at'] as String,
      );

  Book copyWith({
    String? id,
    String? name,
    String? icon,
    String? color,
    int? type,
    bool? isShared,
    String? createdAt,
    String? updatedAt,
  }) =>
      Book(
        id: id ?? this.id,
        name: name ?? this.name,
        icon: icon ?? this.icon,
        color: color ?? this.color,
        type: type ?? this.type,
        isShared: isShared ?? this.isShared,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
