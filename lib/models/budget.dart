class Budget {
  final String id;
  final String month;
  final int totalAmount;
  final String? categoryId;
  final String createdAt;
  final String updatedAt;

  const Budget({
    required this.id,
    required this.month,
    required this.totalAmount,
    this.categoryId,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'month': month,
        'total_amount': totalAmount,
        'category_id': categoryId,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory Budget.fromMap(Map<String, dynamic> map) => Budget(
        id: map['id'] as String,
        month: map['month'] as String,
        totalAmount: map['total_amount'] as int,
        categoryId: map['category_id'] as String?,
        createdAt: map['created_at'] as String,
        updatedAt: map['updated_at'] as String,
      );

  Budget copyWith({
    String? id,
    String? month,
    int? totalAmount,
    String? categoryId,
    String? createdAt,
    String? updatedAt,
  }) =>
      Budget(
        id: id ?? this.id,
        month: month ?? this.month,
        totalAmount: totalAmount ?? this.totalAmount,
        categoryId: categoryId ?? this.categoryId,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
