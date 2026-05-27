class SharedAuditLog {
  final String id;
  final String bookId;
  final String memberName;
  final String action;
  final String? targetType;
  final String? targetId;
  final String? detail;
  final String createdAt;

  const SharedAuditLog({
    required this.id,
    required this.bookId,
    required this.memberName,
    required this.action,
    this.targetType,
    this.targetId,
    this.detail,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'book_id': bookId,
        'member_name': memberName,
        'action': action,
        'target_type': targetType,
        'target_id': targetId,
        'detail': detail,
        'created_at': createdAt,
      };

  factory SharedAuditLog.fromMap(Map<String, dynamic> map) => SharedAuditLog(
        id: map['id'] as String,
        bookId: map['book_id'] as String,
        memberName: map['member_name'] as String,
        action: map['action'] as String,
        targetType: map['target_type'] as String?,
        targetId: map['target_id'] as String?,
        detail: map['detail'] as String?,
        createdAt: map['created_at'] as String,
      );
}
