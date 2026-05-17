class PeriodicTransaction {
  final String id;
  final int type; // 0=expense, 1=income
  final int amount; // cents
  final String categoryId;
  final String? accountId;
  final String bookId;
  final String? note;
  final int frequency; // 0=daily, 1=weekly, 2=monthly, 3=yearly, 4=custom
  final int? customDays;
  final bool isWorkdayOnly;
  final String nextDate; // ISO 8601
  final bool isActive;
  final bool autoConfirm;
  final String createdAt;
  final String updatedAt;

  const PeriodicTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.categoryId,
    this.accountId,
    this.bookId = 'default',
    this.note,
    required this.frequency,
    this.customDays,
    this.isWorkdayOnly = false,
    required this.nextDate,
    this.isActive = true,
    this.autoConfirm = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'amount': amount,
        'category_id': categoryId,
        'account_id': accountId,
        'book_id': bookId,
        'note': note,
        'frequency': frequency,
        'custom_days': customDays,
        'is_workday_only': isWorkdayOnly ? 1 : 0,
        'next_date': nextDate,
        'is_active': isActive ? 1 : 0,
        'auto_confirm': autoConfirm ? 1 : 0,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory PeriodicTransaction.fromMap(Map<String, dynamic> map) =>
      PeriodicTransaction(
        id: map['id'] as String,
        type: map['type'] as int,
        amount: map['amount'] as int,
        categoryId: map['category_id'] as String,
        accountId: map['account_id'] as String?,
        bookId: (map['book_id'] as String?) ?? 'default',
        note: map['note'] as String?,
        frequency: map['frequency'] as int,
        customDays: map['custom_days'] as int?,
        isWorkdayOnly: (map['is_workday_only'] as int?) == 1,
        nextDate: map['next_date'] as String,
        isActive: (map['is_active'] as int?) != 0,
        autoConfirm: (map['auto_confirm'] as int?) != 0,
        createdAt: map['created_at'] as String,
        updatedAt: map['updated_at'] as String,
      );

  PeriodicTransaction copyWith({
    String? id,
    int? type,
    int? amount,
    String? categoryId,
    String? accountId,
    String? bookId,
    String? note,
    int? frequency,
    int? customDays,
    bool? isWorkdayOnly,
    String? nextDate,
    bool? isActive,
    bool? autoConfirm,
    String? createdAt,
    String? updatedAt,
  }) =>
      PeriodicTransaction(
        id: id ?? this.id,
        type: type ?? this.type,
        amount: amount ?? this.amount,
        categoryId: categoryId ?? this.categoryId,
        accountId: accountId ?? this.accountId,
        bookId: bookId ?? this.bookId,
        note: note ?? this.note,
        frequency: frequency ?? this.frequency,
        customDays: customDays ?? this.customDays,
        isWorkdayOnly: isWorkdayOnly ?? this.isWorkdayOnly,
        nextDate: nextDate ?? this.nextDate,
        isActive: isActive ?? this.isActive,
        autoConfirm: autoConfirm ?? this.autoConfirm,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  String get frequencyLabel {
    switch (frequency) {
      case 0: return '每天';
      case 1: return '每周';
      case 2: return '每月';
      case 3: return '每年';
      case 4: return '每${customDays ?? 1}天';
      default: return '未知';
    }
  }
}
