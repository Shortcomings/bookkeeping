import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../models/account.dart';
import '../models/budget.dart';

class TransactionProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();
  final Uuid _uuid = const Uuid();

  List<Transaction> _transactions = [];
  List<Category> _categories = [];
  List<Account> _accounts = [];
  bool _loading = false;

  List<Transaction> get transactions => _transactions;
  List<Category> get categories =>
      _categories.where((c) => c.isEnabled).toList();
  List<Category> get expenseCategories =>
      categories.where((c) => c.type == 0).toList();
  List<Category> get incomeCategories =>
      categories.where((c) => c.type == 1).toList();
  List<Account> get accounts =>
      _accounts.where((a) => a.isEnabled).toList();
  bool get loading => _loading;

  // ==================== 初始化 ====================

  Future<void> init() async {
    _loading = true;
    notifyListeners();
    await Future.wait([loadCategories(), loadAccounts()]);
    await loadTransactions();
    _loading = false;
    notifyListeners();
  }

  // ==================== 交易记录 ====================

  Future<void> loadTransactions() async {
    final db = await _db.database;
    final maps = await db.query('transactions', orderBy: 'date DESC');
    _transactions = maps.map((m) => Transaction.fromMap(m)).toList();
    notifyListeners();
  }

  Future<void> addTransaction({
    required int type,
    required int amount,
    required String date,
    required String categoryId,
    String? accountId,
    String bookId = 'default',
    String? note,
    String? tags,
  }) async {
    final now = DateTime.now().toIso8601String();
    final tx = Transaction(
      id: _uuid.v4(),
      type: type,
      amount: amount,
      date: date,
      categoryId: categoryId,
      accountId: accountId,
      bookId: bookId,
      note: note,
      tags: tags,
      createdAt: now,
      updatedAt: now,
    );

    final db = await _db.database;
    await db.insert('transactions', tx.toMap());

    // 更新账户余额
    if (accountId != null) {
      await _updateAccountBalance(db, accountId, type == 0 ? -amount : amount);
    }

    _transactions.insert(0, tx);
    notifyListeners();
  }

  Future<void> updateTransaction(Transaction tx) async {
    final db = await _db.database;
    final oldTx = _transactions.firstWhere((t) => t.id == tx.id);

    // 回退旧账户余额
    if (oldTx.accountId != null) {
      final oldAmount = oldTx.type == 0 ? oldTx.amount : -oldTx.amount;
      await _updateAccountBalance(db, oldTx.accountId!, oldAmount);
    }

    // 应用新账户余额
    if (tx.accountId != null) {
      final newAmount = tx.type == 0 ? -tx.amount : tx.amount;
      await _updateAccountBalance(db, tx.accountId!, newAmount);
    }

    await db.update(
      'transactions',
      tx.copyWith(updatedAt: DateTime.now().toIso8601String()).toMap(),
      where: 'id = ?',
      whereArgs: [tx.id],
    );

    final index = _transactions.indexWhere((t) => t.id == tx.id);
    if (index != -1) {
      _transactions[index] = tx;
    }
    notifyListeners();
  }

  Future<void> deleteTransaction(String id) async {
    final db = await _db.database;
    final tx = _transactions.firstWhere((t) => t.id == id);

    // 回退账户余额
    if (tx.accountId != null) {
      final amount = tx.type == 0 ? tx.amount : -tx.amount;
      await _updateAccountBalance(db, tx.accountId!, amount);
    }

    await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
    _transactions.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  Future<void> _updateAccountBalance(
      Database db, String accountId, int delta) async {
    await db.rawUpdate(
      'UPDATE accounts SET balance = balance + ?, updated_at = ? WHERE id = ?',
      [delta, DateTime.now().toIso8601String(), accountId],
    );
  }

  // ==================== 分类 ====================

  Future<void> loadCategories() async {
    final db = await _db.database;
    final maps =
        await db.query('categories', orderBy: 'type ASC, sort_order ASC');
    _categories = maps.map((m) => Category.fromMap(m)).toList();
    notifyListeners();
  }

  Future<void> addCategory({
    required String name,
    required int type,
    String icon = '0xe5d3',
    String color = '0xFF5C6BC0',
    String? parentId,
  }) async {
    final now = DateTime.now().toIso8601String();
    final category = Category(
      id: _uuid.v4(),
      name: name,
      type: type,
      icon: icon,
      color: color,
      parentId: parentId,
      sortOrder: _categories.length,
      createdAt: now,
      updatedAt: now,
    );

    final db = await _db.database;
    await db.insert('categories', category.toMap());
    _categories.add(category);
    notifyListeners();
  }

  Category? getCategoryById(String id) {
    try {
      return _categories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  List<Category> get allCategories => List.unmodifiable(_categories);

  List<Category> get rootCategories =>
      _categories.where((c) => c.parentId == null).toList();

  List<Category> getChildCategories(String parentId) =>
      _categories.where((c) => c.parentId == parentId).toList();

  Future<void> updateCategory(Category category) async {
    final db = await _db.database;
    await db.update(
      'categories',
      category.copyWith(updatedAt: DateTime.now().toIso8601String()).toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
    final index = _categories.indexWhere((c) => c.id == category.id);
    if (index != -1) _categories[index] = category;
    notifyListeners();
  }

  Future<void> deleteCategory(String id) async {
    // 检查是否有交易记录引用此分类
    final hasTransactions =
        _transactions.any((t) => t.categoryId == id);
    if (hasTransactions) return; // 有引用时不允许删除

    final db = await _db.database;
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
    _categories.removeWhere((c) => c.id == id);
    // 同时删除子分类
    _categories.removeWhere((c) => c.parentId == id);
    notifyListeners();
  }

  Future<void> toggleCategoryEnabled(String id, bool enabled) async {
    final cat = getCategoryById(id);
    if (cat == null) return;
    final updated = cat.copyWith(isEnabled: enabled);
    await updateCategory(updated);
  }

  Future<void> reorderCategories(List<String> orderedIds) async {
    final db = await _db.database;
    for (int i = 0; i < orderedIds.length; i++) {
      await db.update(
        'categories',
        {'sort_order': i, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [orderedIds[i]],
      );
      final index = _categories.indexWhere((c) => c.id == orderedIds[i]);
      if (index != -1) {
        _categories[index] =
            _categories[index].copyWith(sortOrder: i);
      }
    }
    _categories.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    notifyListeners();
  }

  // ==================== 账户 ====================

  Future<void> loadAccounts() async {
    final db = await _db.database;
    final maps = await db.query('accounts');
    _accounts = maps.map((m) => Account.fromMap(m)).toList();
    notifyListeners();
  }

  Account? getAccountById(String id) {
    try {
      return _accounts.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  List<Account> get allAccounts => List.unmodifiable(_accounts);

  double get netWorth {
    int totalAssets = 0;
    int totalLiabilities = 0;
    for (final a in _accounts) {
      if (a.type == 2) {
        // 信用卡：负余额为欠款（负债）
        totalLiabilities += a.balance < 0 ? -a.balance : 0;
      } else if (a.balance > 0) {
        totalAssets += a.balance;
      } else {
        totalLiabilities += -a.balance;
      }
    }
    return (totalAssets - totalLiabilities) / 100.0;
  }

  Future<void> addAccount({
    required String name,
    required int type,
    String icon = '0xe3c8',
    String color = '0xFF5C6BC0',
    int balance = 0,
    int? creditLimit,
    int? billDate,
    int? dueDate,
  }) async {
    final now = DateTime.now().toIso8601String();
    final account = Account(
      id: _uuid.v4(),
      name: name,
      type: type,
      balance: balance,
      icon: icon,
      color: color,
      creditLimit: creditLimit,
      billDate: billDate,
      dueDate: dueDate,
      createdAt: now,
      updatedAt: now,
    );
    final db = await _db.database;
    await db.insert('accounts', account.toMap());
    _accounts.add(account);
    notifyListeners();
  }

  Future<void> updateAccount(Account account) async {
    final db = await _db.database;
    await db.update(
      'accounts',
      account.copyWith(updatedAt: DateTime.now().toIso8601String()).toMap(),
      where: 'id = ?',
      whereArgs: [account.id],
    );
    final index = _accounts.indexWhere((a) => a.id == account.id);
    if (index != -1) _accounts[index] = account;
    notifyListeners();
  }

  Future<void> deleteAccount(String id) async {
    final hasTransactions = _transactions.any((t) => t.accountId == id);
    if (hasTransactions) return;
    final db = await _db.database;
    await db.delete('accounts', where: 'id = ?', whereArgs: [id]);
    _accounts.removeWhere((a) => a.id == id);
    notifyListeners();
  }

  Future<void> transferBetweenAccounts({
    required String fromAccountId,
    required String toAccountId,
    required int amount,
  }) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();
      // 转出
      await txn.rawUpdate(
        'UPDATE accounts SET balance = balance - ?, updated_at = ? WHERE id = ?',
        [amount, now, fromAccountId],
      );
      // 转入
      await txn.rawUpdate(
        'UPDATE accounts SET balance = balance + ?, updated_at = ? WHERE id = ?',
        [amount, now, toAccountId],
      );
    });
    // 更新内存
    final fromIdx = _accounts.indexWhere((a) => a.id == fromAccountId);
    if (fromIdx != -1) {
      _accounts[fromIdx] = _accounts[fromIdx].copyWith(
        balance: _accounts[fromIdx].balance - amount,
      );
    }
    final toIdx = _accounts.indexWhere((a) => a.id == toAccountId);
    if (toIdx != -1) {
      _accounts[toIdx] = _accounts[toIdx].copyWith(
        balance: _accounts[toIdx].balance + amount,
      );
    }
    notifyListeners();
  }

  // ==================== 统计 ====================

  Future<Map<String, int>> getCategoryTotals(
      int type, String startDate, String endDate) async {
    final db = await _db.database;
    final result = await db.rawQuery('''
      SELECT category_id, SUM(amount) as total
      FROM transactions
      WHERE type = ? AND date >= ? AND date <= ? AND is_refund = 0
      GROUP BY category_id
    ''', [type, startDate, endDate]);

    final map = <String, int>{};
    for (final row in result) {
      map[row['category_id'] as String] = (row['total'] as int?) ?? 0;
    }
    return map;
  }

  Future<int> getTotalAmount(int type, String startDate, String endDate) async {
    final db = await _db.database;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM transactions
      WHERE type = ? AND date >= ? AND date <= ? AND is_refund = 0
    ''', [type, startDate, endDate]);
    return (result.first['total'] as int?) ?? 0;
  }

  // ==================== 查询 ====================

  List<Transaction> getTransactionsByDate(String date) {
    return _transactions.where((t) => t.date == date).toList();
  }

  List<Transaction> getTransactionsByMonth(int year, int month) {
    final prefix = '$year-${month.toString().padLeft(2, '0')}';
    return _transactions.where((t) => t.date.startsWith(prefix)).toList();
  }

  Map<String, List<Transaction>> getGroupedTransactions() {
    final map = <String, List<Transaction>>{};
    for (final tx in _transactions) {
      map.putIfAbsent(tx.date, () => []).add(tx);
    }
    return map;
  }

  // ==================== 预算 ====================

  List<Budget> _budgets = [];

  Future<void> loadBudgets(String month) async {
    final db = await _db.database;
    final maps = await db.query('budgets', where: 'month = ?', whereArgs: [month]);
    _budgets = maps.map((m) => Budget.fromMap(m)).toList();
    notifyListeners();
  }

  Budget? getTotalBudget(String month) {
    try {
      return _budgets.firstWhere(
          (b) => b.month == month && b.categoryId == null);
    } catch (_) {
      return null;
    }
  }

  List<Budget> getCategoryBudgets(String month) {
    return _budgets
        .where((b) => b.month == month && b.categoryId != null)
        .toList();
  }

  Future<void> setTotalBudget(String month, int totalAmount) async {
    final db = await _db.database;
    final now = DateTime.now().toIso8601String();
    final existing = _budgets
        .where((b) => b.month == month && b.categoryId == null)
        .toList();

    if (existing.isNotEmpty) {
      final updated = existing.first.copyWith(totalAmount: totalAmount);
      await db.update('budgets', updated.toMap(),
          where: 'id = ?', whereArgs: [updated.id]);
      final idx = _budgets.indexOf(existing.first);
      _budgets[idx] = updated;
    } else {
      final budget = Budget(
        id: _uuid.v4(),
        month: month,
        totalAmount: totalAmount,
        categoryId: null,
        createdAt: now,
        updatedAt: now,
      );
      await db.insert('budgets', budget.toMap());
      _budgets.add(budget);
    }
    notifyListeners();
  }

  Future<void> setCategoryBudget(
      String month, String categoryId, int amount) async {
    final db = await _db.database;
    final now = DateTime.now().toIso8601String();
    final existing = _budgets
        .where((b) =>
            b.month == month && b.categoryId == categoryId)
        .toList();

    if (amount <= 0) {
      // 删除预算
      if (existing.isNotEmpty) {
        await db.delete('budgets', where: 'id = ?', whereArgs: [existing.first.id]);
        _budgets.remove(existing.first);
      }
    } else if (existing.isNotEmpty) {
      final updated = existing.first.copyWith(totalAmount: amount);
      await db.update('budgets', updated.toMap(),
          where: 'id = ?', whereArgs: [updated.id]);
      final idx = _budgets.indexOf(existing.first);
      _budgets[idx] = updated;
    } else {
      final budget = Budget(
        id: _uuid.v4(),
        month: month,
        totalAmount: totalAmount,
        categoryId: categoryId,
        createdAt: now,
        updatedAt: now,
      );
      await db.insert('budgets', budget.toMap());
      _budgets.add(budget);
    }
    notifyListeners();
  }

  double getBudgetProgress(String month) {
    final budget = getTotalBudget(month);
    if (budget == null || budget.totalAmount == 0) return 0;
    final expense = getTransactionsByMonthString(month)
        .where((t) => t.type == 0)
        .fold<int>(0, (s, t) => s + t.amount);
    return expense / budget.totalAmount;
  }

  double getCategoryBudgetProgress(String month, String categoryId) {
    final budgets = getCategoryBudgets(month);
    final budget = budgets.firstWhere(
      (b) => b.categoryId == categoryId,
      orElse: () => Budget(
        id: '', month: month, totalAmount: 0, createdAt: '', updatedAt: '',
      ),
    );
    if (budget.totalAmount == 0) return 0;
    final expense = getTransactionsByMonthString(month)
        .where((t) => t.type == 0 && t.categoryId == categoryId)
        .fold<int>(0, (s, t) => s + t.amount);
    return expense / budget.totalAmount;
  }

  double getDailyAverageBudget(String month) {
    final budget = getTotalBudget(month);
    if (budget == null) return 0;
    final days = _daysInMonth(month);
    return budget.totalAmount / days;
  }

  double getDailyAverageExpense(String month) {
    final now = DateTime.now();
    final days = now.day;
    final expense = getTransactionsByMonthString(month)
        .where((t) => t.type == 0)
        .fold<int>(0, (s, t) => s + t.amount);
    return days > 0 ? expense / days : 0;
  }

  int _daysInMonth(String month) {
    final parts = month.split('-');
    final y = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    return DateTime(y, m + 1, 0).day;
  }

  List<Transaction> getTransactionsByMonthString(String month) {
    return _transactions.where((t) => t.date.startsWith(month)).toList();
  }

  // ==================== 对比统计 ====================

  Map<int, int> getMonthlyTotals(int type, int year) {
    final map = <int, int>{};
    for (final tx in _transactions) {
      if (tx.type == type) {
        final d = DateTime.tryParse(tx.date);
        if (d != null && d.year == year) {
          map[d.month] = (map[d.month] ?? 0) + tx.amount;
        }
      }
    }
    return map;
  }

  int getYearTotal(int type, int year) {
    int total = 0;
    for (final tx in _transactions) {
      if (tx.type == type) {
        final d = DateTime.tryParse(tx.date);
        if (d != null && d.year == year) {
          total += tx.amount;
        }
      }
    }
    return total;
  }

  List<MonthSummary> getLast12MonthsTrend() {
    final now = DateTime.now();
    final result = <MonthSummary>[];
    for (int i = 11; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i, 1);
      final month = DateFormat('yyyy-MM').format(d);
      final txs = getTransactionsByMonthString(month);
      final expense =
          txs.where((t) => t.type == 0).fold<int>(0, (s, t) => s + t.amount);
      final income =
          txs.where((t) => t.type == 1).fold<int>(0, (s, t) => s + t.amount);
      result.add(MonthSummary(
        month: '${d.month}月',
        expense: expense,
        income: income,
      ));
    }
    return result;
  }

  List<CategoryComparison> getTopCategoryChanges(
      String currentMonth, String previousMonth) {
    final currentTxs = getTransactionsByMonthString(currentMonth)
        .where((t) => t.type == 0)
        .toList();
    final prevTxs = getTransactionsByMonthString(previousMonth)
        .where((t) => t.type == 0)
        .toList();

    final currentByCat = <String, int>{};
    for (final tx in currentTxs) {
      currentByCat[tx.categoryId] =
          (currentByCat[tx.categoryId] ?? 0) + tx.amount;
    }
    final prevByCat = <String, int>{};
    for (final tx in prevTxs) {
      prevByCat[tx.categoryId] =
          (prevByCat[tx.categoryId] ?? 0) + tx.amount;
    }

    final comparisons = <CategoryComparison>[];
    for (final entry in currentByCat.entries) {
      final prev = prevByCat[entry.key] ?? 0;
      final change =
          prev > 0 ? (entry.value - prev) / prev * 100 : 100.0;
      comparisons.add(CategoryComparison(
        categoryId: entry.key,
        currentAmount: entry.value,
        previousAmount: prev,
        changePercent: change,
      ));
    }
    comparisons.sort((a, b) => b.currentAmount.compareTo(a.currentAmount));
    return comparisons.take(5).toList();
  }

  // ==================== 搜索筛选 ====================

  List<Transaction> searchTransactions({
    String? keyword,
    String? startDate,
    String? endDate,
    int? typeFilter,
    int? minAmount,
    int? maxAmount,
    String? accountId,
    String? categoryId,
  }) {
    return _transactions.where((tx) {
      if (keyword != null && keyword.isNotEmpty) {
        final kw = keyword.toLowerCase();
        final cat = getCategoryById(tx.categoryId);
        final matchesNote =
            (tx.note ?? '').toLowerCase().contains(kw);
        final matchesCat =
            (cat?.name ?? '').toLowerCase().contains(kw);
        final matchesAmount =
            (tx.amount / 100).toStringAsFixed(2).contains(kw);
        if (!matchesNote && !matchesCat && !matchesAmount) return false;
      }
      if (startDate != null && tx.date.compareTo(startDate) < 0) {
        return false;
      }
      if (endDate != null && tx.date.compareTo(endDate) > 0) return false;
      if (typeFilter != null && tx.type != typeFilter) return false;
      if (minAmount != null && tx.amount < minAmount) return false;
      if (maxAmount != null && tx.amount > maxAmount) return false;
      if (accountId != null && tx.accountId != accountId) return false;
      if (categoryId != null && tx.categoryId != categoryId) return false;
      return true;
    }).toList();
  }
}

class MonthSummary {
  final String month;
  final int expense;
  final int income;
  const MonthSummary({
    required this.month,
    required this.expense,
    required this.income,
  });
}

class CategoryComparison {
  final String categoryId;
  final int currentAmount;
  final int previousAmount;
  final double changePercent;
  const CategoryComparison({
    required this.categoryId,
    required this.currentAmount,
    required this.previousAmount,
    required this.changePercent,
  });
}
