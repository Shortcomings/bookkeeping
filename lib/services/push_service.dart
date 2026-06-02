import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../providers/transaction_provider.dart';

class PushConfig {
  final int id;
  final String provider;
  final String pushKey;
  final bool dailySummaryEnabled;
  final bool budgetAlertEnabled;
  final int budgetAlertPct;
  final String? lastDailyPushDate;
  final String? lastBudgetAlertDate;
  final String feedbackKey;
  final String defaultUserName;

  const PushConfig({
    this.id = 1,
    this.provider = 'serverchan',
    this.pushKey = '',
    this.dailySummaryEnabled = false,
    this.budgetAlertEnabled = false,
    this.budgetAlertPct = 80,
    this.lastDailyPushDate,
    this.lastBudgetAlertDate,
    this.feedbackKey = '',
    this.defaultUserName = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'provider': provider,
        'push_key': pushKey,
        'daily_summary_enabled': dailySummaryEnabled ? 1 : 0,
        'budget_alert_enabled': budgetAlertEnabled ? 1 : 0,
        'budget_alert_pct': budgetAlertPct,
        'last_daily_push_date': lastDailyPushDate,
        'last_budget_alert_date': lastBudgetAlertDate,
        'feedback_key': feedbackKey,
        'default_user_name': defaultUserName,
      };

  factory PushConfig.fromMap(Map<String, dynamic> map) => PushConfig(
        id: map['id'] as int,
        provider: (map['provider'] as String?) ?? 'serverchan',
        pushKey: (map['push_key'] as String?) ?? '',
        dailySummaryEnabled: (map['daily_summary_enabled'] as int?) == 1,
        budgetAlertEnabled: (map['budget_alert_enabled'] as int?) == 1,
        budgetAlertPct: (map['budget_alert_pct'] as int?) ?? 80,
        lastDailyPushDate: map['last_daily_push_date'] as String?,
        lastBudgetAlertDate: map['last_budget_alert_date'] as String?,
        feedbackKey: (map['feedback_key'] as String?) ?? '',
        defaultUserName: (map['default_user_name'] as String?) ?? '',
      );

  bool get isConfigured => pushKey.isNotEmpty;
}

class PushService {
  static final PushService _instance = PushService._();
  factory PushService() => _instance;
  PushService._();

  final _db = DatabaseHelper();
  PushConfig? _config;

  Future<void> initialize([TransactionProvider? provider]) async {
    await _loadConfig();
    if (provider != null && _config != null && _config!.isConfigured) {
      await _checkAndExecuteScheduledPushes(provider);
    }
  }

  Future<void> _loadConfig() async {
    final db = await _db.database;
    final results = await db.query('push_config', where: 'id = 1');
    if (results.isNotEmpty) {
      _config = PushConfig.fromMap(results.first);
    }
  }

  Future<PushConfig> getConfig() async {
    await _loadConfig();
    return _config ?? const PushConfig();
  }

  Future<void> saveConfig(PushConfig config) async {
    final db = await _db.database;
    final now = DateTime.now().toIso8601String();
    final map = config.toMap();
    map['updated_at'] = now;

    final existing = await db.query('push_config', where: 'id = 1');
    if (existing.isEmpty) {
      map['created_at'] = now;
      await db.insert('push_config', map);
    } else {
      await db.update('push_config', map, where: 'id = 1');
    }
    _config = config;
  }

  Future<String> testPush(PushConfig config) async {
    try {
      final today = DateFormat('M月d日').format(DateTime.now());
      return await _send(
        config,
        '记账App — 测试消息',
        '这是一条来自记账App的测试推送\n\n发送时间：$today ${DateFormat('HH:mm').format(DateTime.now())}\n\n配置成功！',
      );
    } catch (e) {
      return '测试失败：$e';
    }
  }

  Future<String> sendDailySummary(TransactionProvider provider, {PushConfig? configOverride}) async {
    final config = configOverride ?? await getConfig();
    if (!config.isConfigured) return '请先配置推送 Key';
    if (!config.dailySummaryEnabled) return '每日推送未开启';

    final today = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(today);
    final yesterday = today.subtract(const Duration(days: 1));
    final yesterdayStr = DateFormat('yyyy-MM-dd').format(yesterday);

    final yesterdayTxs = provider.transactions
        .where((t) => t.date == yesterdayStr)
        .toList();

    final totalExpense = yesterdayTxs
        .where((t) => t.type == 0)
        .fold<int>(0, (s, t) => s + t.amount);
    final totalIncome = yesterdayTxs
        .where((t) => t.type == 1)
        .fold<int>(0, (s, t) => s + t.amount);

    // Category breakdown for expenses
    final expenseByCategory = <String, int>{};
    for (final tx in yesterdayTxs.where((t) => t.type == 0)) {
      final cat = provider.getCategoryById(tx.categoryId);
      final name = cat?.name ?? '其他';
      expenseByCategory[name] = (expenseByCategory[name] ?? 0) + tx.amount;
    }
    final sortedExpense = expenseByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final monthStr = DateFormat('yyyy-MM').format(yesterday);
    final budgetProgress = provider.getBudgetProgress(monthStr);

    final buffer = StringBuffer();
    buffer.writeln('📊 **昨日消费报告**');
    const weekDays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    buffer.writeln('📅 ${yesterday.month}月${yesterday.day}日 ${weekDays[yesterday.weekday - 1]}');
    buffer.writeln();
    buffer.writeln('💰 支出：¥${(totalExpense / 100).toStringAsFixed(2)}');
    buffer.writeln('💵 收入：¥${(totalIncome / 100).toStringAsFixed(2)}');
    if (totalExpense > 0) {
      buffer.writeln();
      buffer.writeln('**分类明细：**');
      for (final e in sortedExpense.take(5)) {
        buffer.writeln('  • ${e.key}：¥${(e.value / 100).toStringAsFixed(2)}');
      }
    }
    if (budgetProgress > 0) {
      buffer.writeln();
      buffer.writeln('📈 本月预算已使用 ${(budgetProgress * 100).toStringAsFixed(0)}%');
    }

    final result = await _send(config, '昨日消费 ¥${(totalExpense / 100).toStringAsFixed(2)}', buffer.toString());

    if (result == 'success') {
      await saveConfig(PushConfig(
        provider: config.provider,
        pushKey: config.pushKey,
        feedbackKey: config.feedbackKey,
        defaultUserName: config.defaultUserName,
        dailySummaryEnabled: config.dailySummaryEnabled,
        budgetAlertEnabled: config.budgetAlertEnabled,
        budgetAlertPct: config.budgetAlertPct,
        lastDailyPushDate: todayStr,
        lastBudgetAlertDate: config.lastBudgetAlertDate,
      ));
    }
    return result;
  }

  Future<void> sendBudgetAlert(TransactionProvider provider, double progress) async {
    final config = await getConfig();
    if (!config.isConfigured || !config.budgetAlertEnabled) return;

    final today = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(today);

    // Don't spam — only one budget alert per day
    if (config.lastBudgetAlertDate == todayStr) return;

    final monthStr = DateFormat('yyyy-MM').format(today);
    final budget = provider.getTotalBudget(monthStr);
    if (budget == null || budget.totalAmount == 0) return;

    final expense = provider.getTransactionsByMonthString(monthStr)
        .where((t) => t.type == 0)
        .fold<int>(0, (s, t) => s + t.amount);
    final remaining = budget.totalAmount - expense;
    final pct = (progress * 100).toStringAsFixed(0);
    final remainingDays = max(1, DateTime(today.year, today.month + 1, 0).day - today.day);
    final dailyBudget = remaining > 0 ? (remaining ~/ remainingDays) : 0;

    final title = progress >= 1.0
        ? '⚠️ 预算已用完！'
        : '⚡ 预算已使用 $pct%';

    final buffer = StringBuffer();
    buffer.writeln('**$title**');
    buffer.writeln();
    buffer.writeln('📊 本月支出：¥${(expense / 100).toStringAsFixed(2)}');
    buffer.writeln('🎯 预算总额：¥${(budget.totalAmount / 100).toStringAsFixed(2)}');
    buffer.writeln('💡 剩余：¥${(remaining / 100).toStringAsFixed(2)}');
    if (dailyBudget > 0) {
      buffer.writeln('📅 日均可用：¥${(dailyBudget / 100).toStringAsFixed(2)}（剩$remainingDays天）');
    }

    await _send(config, title, buffer.toString());

    await saveConfig(PushConfig(
      provider: config.provider,
      pushKey: config.pushKey,
      feedbackKey: config.feedbackKey,
      defaultUserName: config.defaultUserName,
      dailySummaryEnabled: config.dailySummaryEnabled,
      budgetAlertEnabled: config.budgetAlertEnabled,
      budgetAlertPct: config.budgetAlertPct,
      lastDailyPushDate: config.lastDailyPushDate,
      lastBudgetAlertDate: todayStr,
    ));
  }

  Future<void> checkBudgetAfterTransaction(TransactionProvider provider) async {
    final config = await getConfig();
    if (!config.isConfigured || !config.budgetAlertEnabled) return;

    final monthStr = DateFormat('yyyy-MM').format(DateTime.now());
    final progress = provider.getBudgetProgress(monthStr);
    final threshold = config.budgetAlertPct / 100.0;

    if (progress >= threshold) {
      await sendBudgetAlert(provider, progress);
    }
  }

  Future<void> _checkAndExecuteScheduledPushes(TransactionProvider provider) async {
    final config = await getConfig();
    if (!config.isConfigured) return;

    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Daily summary
    if (config.dailySummaryEnabled &&
        (config.lastDailyPushDate == null || config.lastDailyPushDate != todayStr)) {
      await sendDailySummary(provider);
    }
  }

  Future<String> _send(PushConfig config, String title, String content) async {
    try {
      if (config.provider == 'pushplus') {
        final response = await http.post(
          Uri.parse('http://www.pushplus.plus/send'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'token': config.pushKey,
            'title': title,
            'content': content,
            'template': 'markdown',
          }),
        ).timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          final body = jsonDecode(response.body);
          if (body['code'] == 200) return 'success';
          return body['msg'] ?? '发送失败';
        }
        return 'HTTP ${response.statusCode}';
      } else {
        // ServerChan
        final response = await http.post(
          Uri.parse('https://sctapi.ftqq.com/${config.pushKey}.send'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'title': title,
            'desp': content,
          }),
        ).timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          final body = jsonDecode(response.body);
          if (body['code'] == 0) return 'success';
          return body['message'] ?? '发送失败';
        }
        return 'HTTP ${response.statusCode}';
      }
    } catch (e) {
      return '$e';
    }
  }
}

int max(int a, int b) => a > b ? a : b;
