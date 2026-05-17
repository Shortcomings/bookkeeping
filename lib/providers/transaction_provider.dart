import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../models/account.dart';

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
}
