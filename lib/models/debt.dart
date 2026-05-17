class Debt {
  final String id;
  final int type; // 0=借入(我欠别人), 1=借出(别人欠我)
  final String personName;
  final int totalAmount;
  final int remainingAmount;
  final String date;
  final String? expectedRepayDate;
  final String? note;
  final bool isSettled;
  final String createdAt;
  final String updatedAt;

  const Debt({
    required this.id,
    required this.type,
    required this.personName,
    required this.totalAmount,
    required this.remainingAmount,
    required this.date,
    this.expectedRepayDate,
    this.note,
    this.isSettled = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'person_name': personName,
        'total_amount': totalAmount,
        'remaining_amount': remainingAmount,
        'date': date,
        'expected_repay_date': expectedRepayDate,
        'note': note,
        'is_settled': isSettled ? 1 : 0,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory Debt.fromMap(Map<String, dynamic> map) => Debt(
        id: map['id'] as String,
        type: map['type'] as int,
        personName: map['person_name'] as String,
        totalAmount: map['total_amount'] as int,
        remainingAmount: map['remaining_amount'] as int,
        date: map['date'] as String,
        expectedRepayDate: map['expected_repay_date'] as String?,
        note: map['note'] as String?,
        isSettled: (map['is_settled'] as int?) == 1,
        createdAt: map['created_at'] as String,
        updatedAt: map['updated_at'] as String,
      );

  Debt copyWith({
    String? id,
    int? type,
    String? personName,
    int? totalAmount,
    int? remainingAmount,
    String? date,
    String? expectedRepayDate,
    String? note,
    bool? isSettled,
    String? createdAt,
    String? updatedAt,
  }) =>
      Debt(
        id: id ?? this.id,
        type: type ?? this.type,
        personName: personName ?? this.personName,
        totalAmount: totalAmount ?? this.totalAmount,
        remainingAmount: remainingAmount ?? this.remainingAmount,
        date: date ?? this.date,
        expectedRepayDate: expectedRepayDate ?? this.expectedRepayDate,
        note: note ?? this.note,
        isSettled: isSettled ?? this.isSettled,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  bool get isOverdue {
    if (isSettled || expectedRepayDate == null) return false;
    return expectedRepayDate!.compareTo(
            DateTime.now().toIso8601String().substring(0, 10)) <
        0;
  }
}
