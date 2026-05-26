import 'package:flutter/foundation.dart' hide Category;
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart' hide Transaction;
import '../database/database_helper.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../models/account.dart';
import '../models/budget.dart';
import '../models/periodic_transaction.dart';
import '../models/book.dart';
import '../models/debt.dart';
import '../models/debt_repayment.dart';
import '../models/saving_goal.dart';
import '../models/investment.dart';
import '../models/investment_trade.dart';
import '../services/nlp_parser.dart';

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
    await Future.wait([loadCategories(), loadAccounts(), loadBooks(), loadDebts(), loadSavingGoals(), loadInvestments()]);
    await loadTransactions();
    await loadPeriodicTransactions();
    checkAndGeneratePeriodicTransactions();
    _loading = false;
    notifyListeners();
  }

  // ==================== 交易记录 ====================

  Future<void> loadTransactions() async {
    final db = await _db.database;
    final maps = await db.query('transactions',
        where: 'book_id = ?',
        whereArgs: [_currentBookId],
        orderBy: 'date DESC');
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
    learnCategoryFromNote(note, categoryId);
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
    learnCategoryFromNote(tx.note, tx.categoryId);
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
    await db.delete('categories', where: 'parent_id = ?', whereArgs: [id]);
    _categories.removeWhere((c) => c.id == id);
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
        totalAmount: amount,
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

  List<CashFlowMonth> getMonthlyCashFlow() {
    final now = DateTime.now();
    final result = <CashFlowMonth>[];
    for (int i = 11; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i, 1);
      final month = DateFormat('yyyy-MM').format(d);
      final txs = getTransactionsByMonthString(month);
      final expense = txs.where((t) => t.type == 0).fold<int>(0, (s, t) => s + t.amount);
      final income = txs.where((t) => t.type == 1).fold<int>(0, (s, t) => s + t.amount);
      // Calculate net worth at end of month (accounts balance at that point)
      // For simplicity, use current net worth minus cumulative cash flow changes
      result.add(CashFlowMonth(
        month: '$month-01',
        income: income,
        expense: expense,
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

  // ==================== 周期记账 ====================

  List<PeriodicTransaction> _periodicTransactions = [];
  List<PeriodicTransaction> get periodicTransactions =>
      _periodicTransactions;

  Future<void> loadPeriodicTransactions() async {
    final db = await _db.database;
    final maps = await db.query('periodic_transactions',
        orderBy: 'created_at DESC');
    _periodicTransactions =
        maps.map((m) => PeriodicTransaction.fromMap(m)).toList();
    notifyListeners();
  }

  Future<void> addPeriodicTransaction({
    required int type,
    required int amount,
    required String categoryId,
    String? accountId,
    String? bookId,
    String? note,
    required int frequency,
    int? customDays,
    bool isWorkdayOnly = false,
    bool autoConfirm = true,
  }) async {
    final now = DateTime.now().toIso8601String();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final nextDate = _computeNextDateFrom(
        frequency, today, customDays, isWorkdayOnly);
    final pt = PeriodicTransaction(
      id: _uuid.v4(),
      type: type,
      amount: amount,
      categoryId: categoryId,
      accountId: accountId,
      bookId: bookId ?? _currentBookId,
      note: note,
      frequency: frequency,
      customDays: customDays,
      isWorkdayOnly: isWorkdayOnly,
      nextDate: nextDate,
      isActive: true,
      autoConfirm: autoConfirm,
      createdAt: now,
      updatedAt: now,
    );
    final db = await _db.database;
    await db.insert('periodic_transactions', pt.toMap());
    _periodicTransactions.insert(0, pt);
    notifyListeners();
  }

  Future<void> updatePeriodicTransaction(
      PeriodicTransaction pt) async {
    final db = await _db.database;
    await db.update(
      'periodic_transactions',
      pt.copyWith(updatedAt: DateTime.now().toIso8601String()).toMap(),
      where: 'id = ?',
      whereArgs: [pt.id],
    );
    final idx =
        _periodicTransactions.indexWhere((p) => p.id == pt.id);
    if (idx != -1) _periodicTransactions[idx] = pt;
    notifyListeners();
  }

  Future<void> deletePeriodicTransaction(String id) async {
    final db = await _db.database;
    await db.delete('periodic_transactions',
        where: 'id = ?', whereArgs: [id]);
    _periodicTransactions.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  Future<void> togglePeriodicActive(String id, bool active) async {
    final idx =
        _periodicTransactions.indexWhere((p) => p.id == id);
    if (idx == -1) return;
    final pt = _periodicTransactions[idx];
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final updated = pt.copyWith(
      isActive: active,
      nextDate:
          active ? _computeNextDateFrom(pt.frequency, today,
              pt.customDays, pt.isWorkdayOnly) : pt.nextDate,
    );
    await updatePeriodicTransaction(updated);
  }

  Future<int> checkAndGeneratePeriodicTransactions() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final db = await _db.database;
    int generated = 0;

    for (final pt in _periodicTransactions.where((p) => p.isActive)) {
      String nextDate = pt.nextDate;
      int catchUps = 0;
      const maxCatchUp = 90;

      while (nextDate.compareTo(today) <= 0 && catchUps < maxCatchUp) {
        catchUps++;
        // 去重检查
        final existing = await db.rawQuery(
          'SELECT id FROM transactions WHERE periodic_id = ? AND date = ?',
          [pt.id, nextDate],
        );
        if (existing.isEmpty) {
          await _createTransactionFromPeriodic(pt, nextDate, db);
          generated++;
        }
        nextDate = _computeNextDateFrom(
            pt.frequency, nextDate, pt.customDays, pt.isWorkdayOnly);
      }

      if (nextDate != pt.nextDate) {
        await db.update(
          'periodic_transactions',
          {
            'next_date': nextDate,
            'updated_at': DateTime.now().toIso8601String()
          },
          where: 'id = ?',
          whereArgs: [pt.id],
        );
        final idx =
            _periodicTransactions.indexWhere((p) => p.id == pt.id);
        if (idx != -1) {
          _periodicTransactions[idx] =
              _periodicTransactions[idx].copyWith(nextDate: nextDate);
        }
      }
    }
    if (generated > 0) {
      await loadTransactions();
      notifyListeners();
    }
    return generated;
  }

  Future<void> _createTransactionFromPeriodic(
      PeriodicTransaction pt, String date, Database db) async {
    final now = DateTime.now().toIso8601String();
    final note = pt.autoConfirm
        ? (pt.note ?? '')
        : '[待确认]${pt.note ?? ""}';
    final tx = Transaction(
      id: _uuid.v4(),
      type: pt.type,
      amount: pt.amount,
      date: date,
      categoryId: pt.categoryId,
      accountId: pt.accountId,
      bookId: pt.bookId,
      note: note.isNotEmpty ? note : null,
      isPeriodic: true,
      periodicId: pt.id,
      createdAt: now,
      updatedAt: now,
    );
    await db.insert('transactions', tx.toMap());
    if (pt.accountId != null) {
      await db.rawUpdate(
        'UPDATE accounts SET balance = balance + ?, updated_at = ? WHERE id = ?',
        [
          pt.type == 0 ? -pt.amount : pt.amount,
          now,
          pt.accountId
        ],
      );
    }
    _transactions.insert(0, tx);
  }

  String _computeNextDateFrom(int frequency, String fromDateStr,
      int? customDays, bool isWorkdayOnly) {
    DateTime d = DateTime.parse(fromDateStr);
    switch (frequency) {
      case 0:
        d = d.add(const Duration(days: 1));
        break;
      case 1:
        d = d.add(const Duration(days: 7));
        break;
      case 2:
        d = _addMonths(d, 1);
        break;
      case 3:
        d = _addMonths(d, 12);
        break;
      case 4:
        d = d.add(Duration(days: customDays ?? 1));
        break;
    }
    if (isWorkdayOnly) {
      while (d.weekday == DateTime.saturday ||
          d.weekday == DateTime.sunday) {
        d = d.add(const Duration(days: 1));
      }
    }
    return DateFormat('yyyy-MM-dd').format(d);
  }

  DateTime _addMonths(DateTime d, int months) {
    int newMonth = d.month + months;
    int newYear = d.year;
    while (newMonth > 12) {
      newMonth -= 12;
      newYear++;
    }
    int maxDay = DateTime(newYear, newMonth + 1, 0).day;
    int day = d.day > maxDay ? maxDay : d.day;
    return DateTime(newYear, newMonth, day);
  }

  // ==================== 智能分类 ====================

  final Map<String, Map<String, int>> _noteCategoryCounts = {};

  static const _stopWords = {
    '的','了','是','在','我','有','和','就','不','人','都','一','个','这',
    '那','吗','吧','呢','啊','哦','嗯','啦','呀','哈','嘛','很','也','还',
  };

  void learnCategoryFromNote(String? note, String categoryId) {
    if (note == null || note.isEmpty) return;
    final keywords = _extractKeywords(note);
    for (final kw in keywords) {
      _noteCategoryCounts.putIfAbsent(kw, () => {});
      _noteCategoryCounts[kw]![categoryId] =
          (_noteCategoryCounts[kw]![categoryId] ?? 0) + 1;
    }
  }

  String? suggestCategory(String? note) {
    if (note == null || note.isEmpty) return null;
    final keywords = _extractKeywords(note);
    final aggregated = <String, int>{};
    for (final kw in keywords) {
      final counts = _noteCategoryCounts[kw];
      if (counts != null) {
        for (final entry in counts.entries) {
          aggregated[entry.key] =
              (aggregated[entry.key] ?? 0) + entry.value;
        }
      }
    }
    if (aggregated.isEmpty) return null;
    final sorted = aggregated.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (sorted.first.value < 2) return null;
    return sorted.first.key;
  }

  List<String> _extractKeywords(String note) {
    final cleaned = note
        .replaceAll(RegExp(r'[\d.,，。！？、\s]'), '')
        .replaceAll(RegExp(r'[^一-鿿]'), '');
    if (cleaned.isEmpty) return [];
    final keywords = <String>{};
    for (int i = 0; i < cleaned.length; i++) {
      final ch = cleaned[i];
      if (!_stopWords.contains(ch)) {
        keywords.add(ch);
      }
    }
    for (int i = 0; i < cleaned.length - 1; i++) {
      keywords.add(cleaned.substring(i, i + 2));
    }
    return keywords.toList();
  }

  void _checkBudgetAlert() {
    if (_budgets.isEmpty) return;
    // Budget alert is triggered on HomeScreen load, no persistent notification needed
  }

  // ==================== 自动记账导入 ====================

  /// Import a single auto-detected transaction with category matching and dedup.
  /// Returns true if the transaction was actually inserted.
  Future<bool> importAutoTransaction({
    required String merchantName,
    required int amountCents,
    required int type,
    required String date,
    String? sourceApp,
  }) async {
    // 1. Auto-match category
    final match = NlpParser.matchCategoryFromText(merchantName);
    final cats = match.type == 0 ? expenseCategories : incomeCategories;
    final matchedCat = cats.firstWhere(
      (c) => c.name == match.categoryName && c.isEnabled,
      orElse: () => cats.firstWhere(
        (c) => c.name == '其他' && c.isEnabled,
        orElse: () => cats.first,
      ),
    );

    // 2. Duplicate detection: same date + amount + type
    final existing = _transactions.where(
      (t) => t.date == date && t.amount == amountCents && t.type == type,
    );
    if (existing.isNotEmpty) return false;

    // 3. Auto-match account (prefer WeChat/Alipay)
    String? accountId;
    if (sourceApp != null) {
      final named = _accounts.where(
        (a) => a.name.contains(sourceApp) && a.isEnabled,
      );
      if (named.isNotEmpty) accountId = named.first.id;
    }
    accountId ??= _accounts.where((a) => a.isEnabled).firstOrNull?.id;

    // 4. Build note
    final note = '$merchantName${sourceApp != null ? " (来自$sourceApp自动记账)" : ""}';

    // 5. Insert using existing addTransaction flow
    await addTransaction(
      type: type,
      amount: amountCents,
      date: date,
      categoryId: matchedCat.id,
      accountId: accountId,
      note: note,
    );

    return true;
  }

  /// Import multiple auto transactions. Returns count of successfully imported.
  Future<int> importAutoTransactions(
      List<Map<String, dynamic>> transactions) async {
    int count = 0;
    for (final tx in transactions) {
      final success = await importAutoTransaction(
        merchantName: tx['merchantName'] as String,
        amountCents: tx['amountCents'] as int,
        type: tx['type'] as int,
        date: tx['date'] as String,
        sourceApp: tx['sourceApp'] as String?,
      );
      if (success) count++;
    }
    return count;
  }

  // ==================== 多账本 ====================

  List<Book> _books = [];
  List<Book> get books => _books;
  String _currentBookId = 'default';

  String get currentBookId => _currentBookId;

  Future<void> loadBooks() async {
    final db = await _db.database;
    final maps = await db.query('books');
    _books = maps.map((m) => Book.fromMap(m)).toList();
    if (_books.isEmpty) {
      // Create default book if none
      final now = DateTime.now().toIso8601String();
      final defaultBook = Book(
        id: 'default', name: '日常账本', icon: '0xe3cb',
        color: '0xFF5C6BC0', createdAt: now, updatedAt: now,
      );
      await db.insert('books', defaultBook.toMap());
      _books = [defaultBook];
    }
    notifyListeners();
  }

  Book? get currentBook {
    try {
      return _books.firstWhere((b) => b.id == _currentBookId);
    } catch (_) {
      return _books.isNotEmpty ? _books.first : null;
    }
  }

  Future<void> switchBook(String bookId) async {
    _currentBookId = bookId;
    await loadTransactions();
    await loadPeriodicTransactions();
    notifyListeners();
  }

  Future<void> addBook({required String name, String icon = '0xe3cb',
      String color = '0xFF5C6BC0'}) async {
    final now = DateTime.now().toIso8601String();
    final book = Book(id: _uuid.v4(), name: name, icon: icon,
        color: color, createdAt: now, updatedAt: now);
    final db = await _db.database;
    await db.insert('books', book.toMap());
    _books.add(book);
    notifyListeners();
  }

  Future<void> updateBook(Book book) async {
    final db = await _db.database;
    await db.update('books', book.toMap(), where: 'id = ?',
        whereArgs: [book.id]);
    final idx = _books.indexWhere((b) => b.id == book.id);
    if (idx != -1) _books[idx] = book;
    notifyListeners();
  }

  Future<void> deleteBook(String id) async {
    if (id == 'default' || _books.length <= 1) return;
    final db = await _db.database;
    await db.delete('books', where: 'id = ?', whereArgs: [id]);
    await db.delete('transactions', where: 'book_id = ?',
        whereArgs: [id]);
    _books.removeWhere((b) => b.id == id);
    if (_currentBookId == id) {
      _currentBookId = _books.first.id;
      await loadTransactions();
    }
    notifyListeners();
  }

  // ==================== 债务管理 ====================

  List<Debt> _debts = [];
  List<Debt> get debts => _debts;
  List<DebtRepayment> _repayments = [];

  List<DebtRepayment> getRepayments(String debtId) =>
      _repayments.where((r) => r.debtId == debtId).toList();

  Future<void> loadDebts() async {
    final db = await _db.database;
    final maps = await db.query('debts', orderBy: 'date DESC');
    _debts = maps.map((m) => Debt.fromMap(m)).toList();
    final rMaps = await db.query('debt_repayments',
        orderBy: 'date DESC');
    _repayments = rMaps.map((m) => DebtRepayment.fromMap(m)).toList();
    notifyListeners();
  }

  Future<void> addDebt({required int type, required String personName,
      required int amount, required String date,
      String? expectedRepayDate, String? note}) async {
    final now = DateTime.now().toIso8601String();
    final debt = Debt(id: _uuid.v4(), type: type,
        personName: personName, totalAmount: amount,
        remainingAmount: amount, date: date,
        expectedRepayDate: expectedRepayDate, note: note,
        createdAt: now, updatedAt: now);
    final db = await _db.database;
    await db.insert('debts', debt.toMap());
    _debts.insert(0, debt);
    notifyListeners();
  }

  Future<void> updateDebt(Debt debt) async {
    final db = await _db.database;
    await db.update('debts', debt.toMap(), where: 'id = ?',
        whereArgs: [debt.id]);
    final idx = _debts.indexWhere((d) => d.id == debt.id);
    if (idx != -1) _debts[idx] = debt;
    notifyListeners();
  }

  Future<void> deleteDebt(String id) async {
    final db = await _db.database;
    await db.delete('debts', where: 'id = ?', whereArgs: [id]);
    await db.delete('debt_repayments', where: 'debt_id = ?',
        whereArgs: [id]);
    _debts.removeWhere((d) => d.id == id);
    _repayments.removeWhere((r) => r.debtId == id);
    notifyListeners();
  }

  Future<void> addDebtRepayment({required String debtId,
      required int amount, required String date,
      String? note}) async {
    final now = DateTime.now().toIso8601String();
    final repayment = DebtRepayment(id: _uuid.v4(),
        debtId: debtId, amount: amount, date: date, note: note,
        createdAt: now);
    final db = await _db.database;
    await db.insert('debt_repayments', repayment.toMap());
    _repayments.add(repayment);
    // Update remaining amount
    final dIdx = _debts.indexWhere((d) => d.id == debtId);
    if (dIdx != -1) {
      final debt = _debts[dIdx];
      final newRemaining =
          (debt.remainingAmount - amount).clamp(0, debt.totalAmount);
      final updated = debt.copyWith(
        remainingAmount: newRemaining,
        isSettled: newRemaining == 0,
        updatedAt: now,
      );
      await db.update('debts', updated.toMap(),
          where: 'id = ?', whereArgs: [debtId]);
      _debts[dIdx] = updated;
    }
    notifyListeners();
  }

  // ==================== 退���与报销 ====================

  Future<void> refundTransaction(String txId, int amountCents) async {
    final idx = _transactions.indexWhere((t) => t.id == txId);
    if (idx == -1) return;
    final tx = _transactions[idx];
    final now = DateTime.now().toIso8601String();
    // Create refund record (income)
    final refundTx = Transaction(
      id: _uuid.v4(), type: 1, amount: amountCents,
      date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
      categoryId: tx.categoryId, accountId: tx.accountId,
      bookId: tx.bookId, note: '退款: ${tx.note ?? ""}',
      isRefund: true, refundTransactionId: txId,
      createdAt: now, updatedAt: now,
    );
    final db = await _db.database;
    await db.insert('transactions', refundTx.toMap());
    if (tx.accountId != null) {
      await _updateAccountBalance(db, tx.accountId!, amountCents);
    }
    // Mark original
    final updated = tx.copyWith(isRefund: true,
        refundTransactionId: refundTx.id);
    await db.update('transactions', updated.toMap(),
        where: 'id = ?', whereArgs: [txId]);
    _transactions[idx] = updated;
    _transactions.insert(0, refundTx);
    notifyListeners();
  }

  Future<void> markReimbursable(String txId) async {
    final idx = _transactions.indexWhere((t) => t.id == txId);
    if (idx == -1) return;
    final updated = _transactions[idx].copyWith(
        isReimbursed: true, reimbursementStatus: 1);
    final db = await _db.database;
    await db.update('transactions', updated.toMap(),
        where: 'id = ?', whereArgs: [txId]);
    _transactions[idx] = updated;
    notifyListeners();
  }

  Future<void> updateReimbursementStatus(
      String txId, int status) async {
    final idx = _transactions.indexWhere((t) => t.id == txId);
    if (idx == -1) return;
    final updated = _transactions[idx].copyWith(
        reimbursementStatus: status);
    final db = await _db.database;
    await db.update('transactions', updated.toMap(),
        where: 'id = ?', whereArgs: [txId]);
    _transactions[idx] = updated;
    notifyListeners();
  }

  Future<void> completeReimbursement(String txId) async {
    final idx = _transactions.indexWhere((t) => t.id == txId);
    if (idx == -1) return;
    final tx = _transactions[idx];
    final now = DateTime.now().toIso8601String();
    final incomeTx = Transaction(
      id: _uuid.v4(), type: 1, amount: tx.amount,
      date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
      categoryId: tx.categoryId, accountId: tx.accountId,
      bookId: tx.bookId, note: '报销: ${tx.note ?? ""}',
      createdAt: now, updatedAt: now,
    );
    final db = await _db.database;
    await db.insert('transactions', incomeTx.toMap());
    if (tx.accountId != null) {
      await _updateAccountBalance(db, tx.accountId!, tx.amount);
    }
    final updated = tx.copyWith(reimbursementStatus: 3);
    await db.update('transactions', updated.toMap(),
        where: 'id = ?', whereArgs: [txId]);
    _transactions[idx] = updated;
    _transactions.insert(0, incomeTx);
    notifyListeners();
  }

  List<Transaction> get reimbursableTransactions =>
      _transactions.where((t) => t.isReimbursed).toList();

  // ==================== 存钱计划 ====================

  List<SavingGoal> _savingGoals = [];
  List<SavingGoal> get savingGoals => _savingGoals;

  Future<void> loadSavingGoals() async {
    final db = await _db.database;
    final maps = await db.query('saving_goals',
        orderBy: 'created_at DESC');
    _savingGoals = maps.map((m) => SavingGoal.fromMap(m)).toList();
    notifyListeners();
  }

  Future<void> addSavingGoal({required String name,
      required int targetAmount, String? deadline,
      String? coverImage}) async {
    final now = DateTime.now().toIso8601String();
    final goal = SavingGoal(id: _uuid.v4(), name: name,
        targetAmount: targetAmount, deadline: deadline,
        coverImage: coverImage, createdAt: now, updatedAt: now);
    final db = await _db.database;
    await db.insert('saving_goals', goal.toMap());
    _savingGoals.insert(0, goal);
    notifyListeners();
  }

  Future<void> updateSavingGoal(SavingGoal goal) async {
    final db = await _db.database;
    await db.update('saving_goals', goal.toMap(),
        where: 'id = ?', whereArgs: [goal.id]);
    final idx = _savingGoals.indexWhere((g) => g.id == goal.id);
    if (idx != -1) _savingGoals[idx] = goal;
    notifyListeners();
  }

  Future<void> deleteSavingGoal(String id) async {
    final db = await _db.database;
    await db.delete('saving_goals', where: 'id = ?',
        whereArgs: [id]);
    _savingGoals.removeWhere((g) => g.id == id);
    notifyListeners();
  }

  Future<void> addSavingAmount(String goalId, int amount) async {
    final idx = _savingGoals.indexWhere((g) => g.id == goalId);
    if (idx == -1) return;
    final goal = _savingGoals[idx];
    final newAmount = goal.currentAmount + amount;
    final updated = goal.copyWith(
      currentAmount: newAmount,
      isCompleted: newAmount >= goal.targetAmount,
      updatedAt: DateTime.now().toIso8601String(),
    );
    final db = await _db.database;
    await db.update('saving_goals', updated.toMap(),
        where: 'id = ?', whereArgs: [goalId]);
    _savingGoals[idx] = updated;
    notifyListeners();
  }

  // ==================== 投资记录 ====================

  List<Investment> _investments = [];
  List<InvestmentTrade> _trades = [];

  List<Investment> get investments => _investments;
  List<InvestmentTrade> getTrades(String investmentId) =>
      _trades.where((t) => t.investmentId == investmentId).toList();

  Future<void> loadInvestments() async {
    final db = await _db.database;
    final maps = await db.query('investments', orderBy: 'created_at DESC');
    _investments = maps.map((m) => Investment.fromMap(m)).toList();
    final tMaps = await db.query('investment_trades', orderBy: 'date DESC');
    _trades = tMaps.map((m) => InvestmentTrade.fromMap(m)).toList();
    notifyListeners();
  }

  Future<void> addInvestment({
    required String accountId,
    required String name,
    String? code,
    required int type,
    required int shares,
    required int costBasis,
    required int currentValue,
    String? note,
  }) async {
    final now = DateTime.now().toIso8601String();
    final inv = Investment(
      id: _uuid.v4(),
      accountId: accountId,
      name: name,
      code: code,
      type: type,
      shares: shares,
      costBasis: costBasis,
      currentValue: currentValue,
      note: note,
      createdAt: now,
      updatedAt: now,
    );
    final db = await _db.database;
    await db.insert('investments', inv.toMap());
    _investments.insert(0, inv);
    notifyListeners();
  }

  Future<void> updateInvestment(Investment inv) async {
    final db = await _db.database;
    await db.update('investments', inv.toMap(), where: 'id = ?', whereArgs: [inv.id]);
    final idx = _investments.indexWhere((i) => i.id == inv.id);
    if (idx != -1) _investments[idx] = inv;
    notifyListeners();
  }

  Future<void> deleteInvestment(String id) async {
    final db = await _db.database;
    await db.delete('investment_trades', where: 'investment_id = ?', whereArgs: [id]);
    await db.delete('investments', where: 'id = ?', whereArgs: [id]);
    _investments.removeWhere((i) => i.id == id);
    _trades.removeWhere((t) => t.investmentId == id);
    notifyListeners();
  }

  Future<void> addTrade({
    required String investmentId,
    required int type,
    required int shares,
    required int price,
    required int amount,
    required String date,
    String? note,
  }) async {
    final now = DateTime.now().toIso8601String();
    final trade = InvestmentTrade(
      id: _uuid.v4(),
      investmentId: investmentId,
      type: type,
      shares: shares,
      price: price,
      amount: amount,
      date: date,
      note: note,
      createdAt: now,
    );
    final db = await _db.database;
    await db.insert('investment_trades', trade.toMap());
    _trades.insert(0, trade);

    // Update holding
    final idx = _investments.indexWhere((i) => i.id == investmentId);
    if (idx != -1) {
      final inv = _investments[idx];
      int newShares = inv.shares;
      int newCostBasis = inv.costBasis;
      int newCurrentValue = inv.currentValue;

      switch (type) {
        case 0: // buy
          newShares += shares;
          newCostBasis += amount;
          newCurrentValue += amount;
          break;
        case 1: // sell
          newShares -= shares;
          final sellRatio = newShares > 0 ? shares / inv.shares : 1.0;
          newCostBasis -= (inv.costBasis * sellRatio).round();
          newCurrentValue = newCostBasis;
          break;
        case 2: // dividend
        case 3: // interest
          break;
      }

      final updated = inv.copyWith(
        shares: newShares.clamp(0, 999999999),
        costBasis: newCostBasis.clamp(0, 999999999),
        currentValue: newCurrentValue.clamp(0, 999999999),
        updatedAt: now,
      );
      await db.update('investments', updated.toMap(), where: 'id = ?', whereArgs: [investmentId]);
      _investments[idx] = updated;
    }
    notifyListeners();
  }

  Future<void> deleteTrade(String tradeId) async {
    final tIdx = _trades.indexWhere((t) => t.id == tradeId);
    if (tIdx == -1) return;
    final trade = _trades[tIdx];
    final db = await _db.database;
    await db.delete('investment_trades', where: 'id = ?', whereArgs: [tradeId]);
    _trades.removeAt(tIdx);

    // Reverse holding update
    final idx = _investments.indexWhere((i) => i.id == trade.investmentId);
    if (idx != -1) {
      final inv = _investments[idx];
      int newShares = inv.shares;
      int newCostBasis = inv.costBasis;

      switch (trade.type) {
        case 0: // reverse buy
          newShares -= trade.shares;
          newCostBasis -= trade.amount;
          break;
        case 1: // reverse sell
          newShares += trade.shares;
          newCostBasis += trade.amount;
          break;
        default:
          break;
      }

      final updated = inv.copyWith(
        shares: newShares.clamp(0, 999999999),
        costBasis: newCostBasis.clamp(0, 999999999),
        updatedAt: DateTime.now().toIso8601String(),
      );
      await db.update('investments', updated.toMap(), where: 'id = ?', whereArgs: [trade.investmentId]);
      _investments[idx] = updated;
    }
    notifyListeners();
  }

  int get totalInvestmentValue =>
      _investments.fold(0, (sum, i) => sum + i.currentValue);

  int get totalInvestmentCost =>
      _investments.fold(0, (sum, i) => sum + i.costBasis);

  int get totalInvestmentProfitLoss =>
      totalInvestmentValue - totalInvestmentCost;

}

class CashFlowMonth {
  final String month;
  final int income;
  final int expense;
  const CashFlowMonth({required this.month, required this.income, required this.expense});
  int get net => income - expense;
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
