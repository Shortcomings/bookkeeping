class SavingGoal {
  final String id;
  final String name;
  final int targetAmount;
  final int currentAmount;
  final String? deadline;
  final String? coverImage;
  final bool isCompleted;
  final String createdAt;
  final String updatedAt;

  const SavingGoal({
    required this.id,
    required this.name,
    required this.targetAmount,
    this.currentAmount = 0,
    this.deadline,
    this.coverImage,
    this.isCompleted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  double get progress =>
      targetAmount > 0 ? currentAmount / targetAmount : 0;

  int get remaining =>
      (targetAmount - currentAmount).clamp(0, targetAmount);

  int? get daysLeft {
    if (deadline == null) return null;
    final d = DateTime.tryParse(deadline!);
    if (d == null) return null;
    return d.difference(DateTime.now()).inDays;
  }

  double get dailyNeeded {
    final left = daysLeft;
    if (left == null || left <= 0) return remaining.toDouble();
    return remaining / left / 100;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'target_amount': targetAmount,
        'current_amount': currentAmount,
        'deadline': deadline,
        'cover_image': coverImage,
        'is_completed': isCompleted ? 1 : 0,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory SavingGoal.fromMap(Map<String, dynamic> map) => SavingGoal(
        id: map['id'] as String,
        name: map['name'] as String,
        targetAmount: map['target_amount'] as int,
        currentAmount: (map['current_amount'] as int?) ?? 0,
        deadline: map['deadline'] as String?,
        coverImage: map['cover_image'] as String?,
        isCompleted: (map['is_completed'] as int?) == 1,
        createdAt: map['created_at'] as String,
        updatedAt: map['updated_at'] as String,
      );

  SavingGoal copyWith({
    String? id,
    String? name,
    int? targetAmount,
    int? currentAmount,
    String? deadline,
    String? coverImage,
    bool? isCompleted,
    String? createdAt,
    String? updatedAt,
  }) =>
      SavingGoal(
        id: id ?? this.id,
        name: name ?? this.name,
        targetAmount: targetAmount ?? this.targetAmount,
        currentAmount: currentAmount ?? this.currentAmount,
        deadline: deadline ?? this.deadline,
        coverImage: coverImage ?? this.coverImage,
        isCompleted: isCompleted ?? this.isCompleted,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
