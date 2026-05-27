class SharedMember {
  final String id;
  final String bookId;
  final String name;
  final int role; // 0=创建者, 1=管理员, 2=普通成员
  final String joinedAt;

  const SharedMember({
    required this.id,
    required this.bookId,
    required this.name,
    this.role = 2,
    required this.joinedAt,
  });

  bool get isCreator => role == 0;
  bool get isAdmin => role <= 1;

  String get roleLabel {
    switch (role) {
      case 0:
        return '创建者';
      case 1:
        return '管理员';
      default:
        return '成员';
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'book_id': bookId,
        'name': name,
        'role': role,
        'joined_at': joinedAt,
      };

  factory SharedMember.fromMap(Map<String, dynamic> map) => SharedMember(
        id: map['id'] as String,
        bookId: map['book_id'] as String,
        name: map['name'] as String,
        role: (map['role'] as int?) ?? 2,
        joinedAt: map['joined_at'] as String,
      );

  SharedMember copyWith({
    String? id,
    String? bookId,
    String? name,
    int? role,
    String? joinedAt,
  }) =>
      SharedMember(
        id: id ?? this.id,
        bookId: bookId ?? this.bookId,
        name: name ?? this.name,
        role: role ?? this.role,
        joinedAt: joinedAt ?? this.joinedAt,
      );
}
