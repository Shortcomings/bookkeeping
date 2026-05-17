class DebtRepayment {
  final String id;
  final String debtId;
  final int amount;
  final String date;
  final String? note;
  final String createdAt;

  const DebtRepayment({
    required this.id,
    required this.debtId,
    required this.amount,
    required this.date,
    this.note,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'debt_id': debtId,
        'amount': amount,
        'date': date,
        'note': note,
        'created_at': createdAt,
      };

  factory DebtRepayment.fromMap(Map<String, dynamic> map) => DebtRepayment(
        id: map['id'] as String,
        debtId: map['debt_id'] as String,
        amount: map['amount'] as int,
        date: map['date'] as String,
        note: map['note'] as String?,
        createdAt: map['created_at'] as String,
      );
}
