class SharedInvitation {
  final String id;
  final String bookId;
  final String code;
  final int role; // 0=创建者, 1=管理员, 2=普通成员
  final bool isActive;
  final String createdAt;
  final String? expiresAt;

  const SharedInvitation({
    required this.id,
    required this.bookId,
    required this.code,
    this.role = 2,
    this.isActive = true,
    required this.createdAt,
    this.expiresAt,
  });

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.parse(expiresAt!).isBefore(DateTime.now());
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'book_id': bookId,
        'code': code,
        'role': role,
        'is_active': isActive ? 1 : 0,
        'created_at': createdAt,
        'expires_at': expiresAt,
      };

  factory SharedInvitation.fromMap(Map<String, dynamic> map) =>
      SharedInvitation(
        id: map['id'] as String,
        bookId: map['book_id'] as String,
        code: map['code'] as String,
        role: (map['role'] as int?) ?? 2,
        isActive: (map['is_active'] as int?) == 1,
        createdAt: map['created_at'] as String,
        expiresAt: map['expires_at'] as String?,
      );

  SharedInvitation copyWith({
    String? id,
    String? bookId,
    String? code,
    int? role,
    bool? isActive,
    String? createdAt,
    String? expiresAt,
  }) =>
      SharedInvitation(
        id: id ?? this.id,
        bookId: bookId ?? this.bookId,
        code: code ?? this.code,
        role: role ?? this.role,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt ?? this.createdAt,
        expiresAt: expiresAt ?? this.expiresAt,
      );
}
