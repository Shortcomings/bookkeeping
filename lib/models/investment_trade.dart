class InvestmentTrade {
  final String id;
  final String investmentId;
  final int type; // 0=buy, 1=sell, 2=dividend, 3=interest
  final int shares; // shares × 1000
  final int price; // per-share price in cents
  final int amount; // total amount in cents
  final String date;
  final String? note;
  final String createdAt;

  const InvestmentTrade({
    required this.id,
    required this.investmentId,
    required this.type,
    required this.shares,
    required this.price,
    required this.amount,
    required this.date,
    this.note,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'investment_id': investmentId,
        'type': type,
        'shares': shares,
        'price': price,
        'amount': amount,
        'date': date,
        'note': note,
        'created_at': createdAt,
      };

  factory InvestmentTrade.fromMap(Map<String, dynamic> map) =>
      InvestmentTrade(
        id: map['id'] as String,
        investmentId: map['investment_id'] as String,
        type: map['type'] as int,
        shares: map['shares'] as int,
        price: map['price'] as int,
        amount: map['amount'] as int,
        date: map['date'] as String,
        note: map['note'] as String?,
        createdAt: map['created_at'] as String,
      );

  InvestmentTrade copyWith({
    String? id,
    String? investmentId,
    int? type,
    int? shares,
    int? price,
    int? amount,
    String? date,
    String? note,
    String? createdAt,
  }) =>
      InvestmentTrade(
        id: id ?? this.id,
        investmentId: investmentId ?? this.investmentId,
        type: type ?? this.type,
        shares: shares ?? this.shares,
        price: price ?? this.price,
        amount: amount ?? this.amount,
        date: date ?? this.date,
        note: note ?? this.note,
        createdAt: createdAt ?? this.createdAt,
      );
}
