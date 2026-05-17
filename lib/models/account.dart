class Account {
  final String id;
  final String name;
  final int type; // 0=cash, 1=debit, 2=credit, 3=stored_value, 4=investment
  final int balance; // stored in cents
  final String currency;
  final String icon;
  final String color;
  final int? creditLimit;
  final int? billDate;
  final int? dueDate;
  final bool isEnabled;
  final String createdAt;
  final String updatedAt;

  const Account({
    required this.id,
    required this.name,
    required this.type,
    this.balance = 0,
    this.currency = 'CNY',
    required this.icon,
    required this.color,
    this.creditLimit,
    this.billDate,
    this.dueDate,
    this.isEnabled = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type,
        'balance': balance,
        'currency': currency,
        'icon': icon,
        'color': color,
        'credit_limit': creditLimit,
        'bill_date': billDate,
        'due_date': dueDate,
        'is_enabled': isEnabled ? 1 : 0,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory Account.fromMap(Map<String, dynamic> map) => Account(
        id: map['id'] as String,
        name: map['name'] as String,
        type: map['type'] as int,
        balance: (map['balance'] as int?) ?? 0,
        currency: (map['currency'] as String?) ?? 'CNY',
        icon: map['icon'] as String,
        color: map['color'] as String,
        creditLimit: map['credit_limit'] as int?,
        billDate: map['bill_date'] as int?,
        dueDate: map['due_date'] as int?,
        isEnabled: (map['is_enabled'] as int?) != 0,
        createdAt: map['created_at'] as String,
        updatedAt: map['updated_at'] as String,
      );

  Account copyWith({
    String? id,
    String? name,
    int? type,
    int? balance,
    String? currency,
    String? icon,
    String? color,
    int? creditLimit,
    int? billDate,
    int? dueDate,
    bool? isEnabled,
    String? createdAt,
    String? updatedAt,
  }) =>
      Account(
        id: id ?? this.id,
        name: name ?? this.name,
        type: type ?? this.type,
        balance: balance ?? this.balance,
        currency: currency ?? this.currency,
        icon: icon ?? this.icon,
        color: color ?? this.color,
        creditLimit: creditLimit ?? this.creditLimit,
        billDate: billDate ?? this.billDate,
        dueDate: dueDate ?? this.dueDate,
        isEnabled: isEnabled ?? this.isEnabled,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
