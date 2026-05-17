class Transaction {
  final String id;
  final int type; // 0=expense, 1=income
  final int amount; // stored in cents
  final String date; // ISO 8601
  final String categoryId;
  final String? accountId;
  final String bookId;
  final String? note;
  final String? tags;
  final bool isRefund;
  final String? refundTransactionId;
  final bool isReimbursed;
  final int reimbursementStatus; // 0=none, 1=pending, 2=submitted, 3=reimbursed
  final bool isPeriodic;
  final String? periodicId;
  final String createdAt;
  final String updatedAt;

  const Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    required this.categoryId,
    this.accountId,
    this.bookId = 'default',
    this.note,
    this.tags,
    this.isRefund = false,
    this.refundTransactionId,
    this.isReimbursed = false,
    this.reimbursementStatus = 0,
    this.isPeriodic = false,
    this.periodicId,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'amount': amount,
        'date': date,
        'category_id': categoryId,
        'account_id': accountId,
        'book_id': bookId,
        'note': note,
        'tags': tags,
        'is_refund': isRefund ? 1 : 0,
        'refund_transaction_id': refundTransactionId,
        'is_reimbursed': isReimbursed ? 1 : 0,
        'reimbursement_status': reimbursementStatus,
        'is_periodic': isPeriodic ? 1 : 0,
        'periodic_id': periodicId,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory Transaction.fromMap(Map<String, dynamic> map) => Transaction(
        id: map['id'] as String,
        type: map['type'] as int,
        amount: map['amount'] as int,
        date: map['date'] as String,
        categoryId: map['category_id'] as String,
        accountId: map['account_id'] as String?,
        bookId: (map['book_id'] as String?) ?? 'default',
        note: map['note'] as String?,
        tags: map['tags'] as String?,
        isRefund: (map['is_refund'] as int?) == 1,
        refundTransactionId: map['refund_transaction_id'] as String?,
        isReimbursed: (map['is_reimbursed'] as int?) == 1,
        reimbursementStatus: (map['reimbursement_status'] as int?) ?? 0,
        isPeriodic: (map['is_periodic'] as int?) == 1,
        periodicId: map['periodic_id'] as String?,
        createdAt: map['created_at'] as String,
        updatedAt: map['updated_at'] as String,
      );

  Transaction copyWith({
    String? id,
    int? type,
    int? amount,
    String? date,
    String? categoryId,
    String? accountId,
    String? bookId,
    String? note,
    String? tags,
    bool? isRefund,
    String? refundTransactionId,
    bool? isReimbursed,
    int? reimbursementStatus,
    bool? isPeriodic,
    String? periodicId,
    String? createdAt,
    String? updatedAt,
  }) =>
      Transaction(
        id: id ?? this.id,
        type: type ?? this.type,
        amount: amount ?? this.amount,
        date: date ?? this.date,
        categoryId: categoryId ?? this.categoryId,
        accountId: accountId ?? this.accountId,
        bookId: bookId ?? this.bookId,
        note: note ?? this.note,
        tags: tags ?? this.tags,
        isRefund: isRefund ?? this.isRefund,
        refundTransactionId: refundTransactionId ?? this.refundTransactionId,
        isReimbursed: isReimbursed ?? this.isReimbursed,
        reimbursementStatus: reimbursementStatus ?? this.reimbursementStatus,
        isPeriodic: isPeriodic ?? this.isPeriodic,
        periodicId: periodicId ?? this.periodicId,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
