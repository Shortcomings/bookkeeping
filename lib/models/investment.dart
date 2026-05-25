class Investment {
  final String id;
  final String accountId;
  final String name;
  final String? code;
  final int type; // 0=stock, 1=fund, 2=crypto, 3=deposit
  final int shares; // shares × 1000
  final int costBasis; // total cost in cents
  final int currentValue; // user-updated market value in cents
  final String currency;
  final String? note;
  final String createdAt;
  final String updatedAt;

  const Investment({
    required this.id,
    required this.accountId,
    required this.name,
    this.code,
    required this.type,
    required this.shares,
    required this.costBasis,
    required this.currentValue,
    this.currency = 'CNY',
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  int get profitLoss => currentValue - costBasis;

  double get profitLossPercent =>
      costBasis > 0 ? (currentValue - costBasis) / costBasis : 0.0;

  double get avgCost =>
      shares > 0 ? costBasis / (shares / 1000) * 100 : 0.0;

  Map<String, dynamic> toMap() => {
        'id': id,
        'account_id': accountId,
        'name': name,
        'code': code,
        'type': type,
        'shares': shares,
        'cost_basis': costBasis,
        'current_value': currentValue,
        'currency': currency,
        'note': note,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory Investment.fromMap(Map<String, dynamic> map) => Investment(
        id: map['id'] as String,
        accountId: map['account_id'] as String,
        name: map['name'] as String,
        code: map['code'] as String?,
        type: map['type'] as int,
        shares: map['shares'] as int,
        costBasis: map['cost_basis'] as int,
        currentValue: map['current_value'] as int,
        currency: (map['currency'] as String?) ?? 'CNY',
        note: map['note'] as String?,
        createdAt: map['created_at'] as String,
        updatedAt: map['updated_at'] as String,
      );

  Investment copyWith({
    String? id,
    String? accountId,
    String? name,
    String? code,
    int? type,
    int? shares,
    int? costBasis,
    int? currentValue,
    String? currency,
    String? note,
    String? createdAt,
    String? updatedAt,
  }) =>
      Investment(
        id: id ?? this.id,
        accountId: accountId ?? this.accountId,
        name: name ?? this.name,
        code: code ?? this.code,
        type: type ?? this.type,
        shares: shares ?? this.shares,
        costBasis: costBasis ?? this.costBasis,
        currentValue: currentValue ?? this.currentValue,
        currency: currency ?? this.currency,
        note: note ?? this.note,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
