import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../providers/transaction_provider.dart';

// ==================== Models ====================

class AIConfig {
  final int id;
  final String provider;
  final String apiKey;
  final String baseUrl;
  final String model;

  const AIConfig({
    this.id = 1,
    required this.provider,
    required this.apiKey,
    required this.baseUrl,
    required this.model,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'provider': provider,
        'api_key': apiKey,
        'base_url': baseUrl,
        'model': model,
      };

  factory AIConfig.fromMap(Map<String, dynamic> map) => AIConfig(
        id: map['id'] as int,
        provider: map['provider'] as String,
        apiKey: map['api_key'] as String,
        baseUrl: map['base_url'] as String,
        model: map['model'] as String,
      );

  bool get isConfigured => apiKey.isNotEmpty;
}

class ChatSession {
  final String id;
  final String title;
  final String createdAt;
  final String updatedAt;

  const ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory ChatSession.fromMap(Map<String, dynamic> map) => ChatSession(
        id: map['id'] as String,
        title: map['title'] as String,
        createdAt: map['created_at'] as String,
        updatedAt: map['updated_at'] as String,
      );
}

class ChatMessage {
  final String id;
  final String sessionId;
  final String role; // 'user' or 'assistant'
  final String content;
  final String createdAt;

  const ChatMessage({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'session_id': sessionId,
        'role': role,
        'content': content,
        'created_at': createdAt,
      };

  factory ChatMessage.fromMap(Map<String, dynamic> map) => ChatMessage(
        id: map['id'] as String,
        sessionId: map['session_id'] as String,
        role: map['role'] as String,
        content: map['content'] as String,
        createdAt: map['created_at'] as String,
      );
}

// ==================== Provider Presets ====================

class AIProvider {
  final String name;
  final String baseUrl;
  final String defaultModel;
  final List<String> models;

  const AIProvider({
    required this.name,
    required this.baseUrl,
    required this.defaultModel,
    required this.models,
  });
}

const aiProviders = [
  AIProvider(
    name: 'DeepSeek',
    baseUrl: 'https://api.deepseek.com/v1',
    defaultModel: 'deepseek-chat',
    models: ['deepseek-chat', 'deepseek-reasoner'],
  ),
  AIProvider(
    name: '通义千问',
    baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
    defaultModel: 'qwen-plus',
    models: ['qwen-plus', 'qwen-max', 'qwen-turbo'],
  ),
  AIProvider(
    name: '智谱 GLM',
    baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
    defaultModel: 'glm-4-flash',
    models: ['glm-4-flash', 'glm-4', 'glm-4-plus'],
  ),
  AIProvider(
    name: 'OpenAI',
    baseUrl: 'https://api.openai.com/v1',
    defaultModel: 'gpt-4o-mini',
    models: ['gpt-4o-mini', 'gpt-4o', 'gpt-3.5-turbo'],
  ),
  AIProvider(
    name: '自定义',
    baseUrl: '',
    defaultModel: '',
    models: [],
  ),
];

// ==================== Service ====================

class AIChatService {
  final DatabaseHelper _db = DatabaseHelper();
  final Uuid _uuid = const Uuid();

  static final AIChatService _instance = AIChatService._();
  factory AIChatService() => _instance;
  AIChatService._();

  // ==================== Config ====================

  Future<AIConfig> loadConfig() async {
    final db = await _db.database;
    final maps = await db.query('ai_config');
    if (maps.isEmpty) {
      final now = DateTime.now().toIso8601String();
      final defaultConfig = AIConfig(
        provider: 'deepseek',
        apiKey: '',
        baseUrl: 'https://api.deepseek.com/v1',
        model: 'deepseek-chat',
      );
      await db.insert('ai_config', {
        ...defaultConfig.toMap(),
        'created_at': now,
        'updated_at': now,
      });
      return defaultConfig;
    }
    return AIConfig.fromMap(maps.first);
  }

  Future<void> saveConfig(AIConfig config) async {
    final db = await _db.database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'ai_config',
      {...config.toMap(), 'updated_at': now},
      where: 'id = ?',
      whereArgs: [config.id],
    );
  }

  Future<String> testConnection(AIConfig config) async {
    try {
      final response = await http.post(
        Uri.parse('${config.baseUrl}/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${config.apiKey}',
        },
        body: jsonEncode({
          'model': config.model,
          'messages': [
            {'role': 'user', 'content': 'Hi'},
          ],
          'max_tokens': 10,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return '连接成功';
      }
      final body = jsonDecode(response.body);
      return '连接失败: ${body['error']?['message'] ?? response.statusCode}';
    } catch (e) {
      return '连接失败: $e';
    }
  }

  // ==================== Chat Sessions ====================

  Future<List<ChatSession>> loadSessions() async {
    final db = await _db.database;
    final maps =
        await db.query('chat_sessions', orderBy: 'updated_at DESC');
    return maps.map((m) => ChatSession.fromMap(m)).toList();
  }

  Future<ChatSession> createSession() async {
    final now = DateTime.now().toIso8601String();
    final session = ChatSession(
      id: _uuid.v4(),
      title: '新对话',
      createdAt: now,
      updatedAt: now,
    );
    final db = await _db.database;
    await db.insert('chat_sessions', session.toMap());
    return session;
  }

  Future<void> updateSessionTitle(String id, String title) async {
    final db = await _db.database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'chat_sessions',
      {'title': title, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteSession(String id) async {
    final db = await _db.database;
    await db.delete('chat_messages', where: 'session_id = ?', whereArgs: [id]);
    await db.delete('chat_sessions', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== Messages ====================

  Future<List<ChatMessage>> loadMessages(String sessionId) async {
    final db = await _db.database;
    final maps = await db.query(
      'chat_messages',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'created_at ASC',
    );
    return maps.map((m) => ChatMessage.fromMap(m)).toList();
  }

  Future<ChatMessage> addMessage({
    required String sessionId,
    required String role,
    required String content,
  }) async {
    final now = DateTime.now().toIso8601String();
    final msg = ChatMessage(
      id: _uuid.v4(),
      sessionId: sessionId,
      role: role,
      content: content,
      createdAt: now,
    );
    final db = await _db.database;
    await db.insert('chat_messages', msg.toMap());
    await db.update(
      'chat_sessions',
      {'updated_at': now},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
    return msg;
  }

  // ==================== Financial Context Builder ====================

  String buildFinancialContext(TransactionProvider provider) {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final monthPrefix = DateFormat('yyyy-MM').format(now);
    final lastMonthPrefix = DateFormat('yyyy-MM')
        .format(DateTime(now.year, now.month - 1, 1));
    final currencyFormat =
        NumberFormat.currency(symbol: '¥', decimalDigits: 2);

    final buf = StringBuffer();
    buf.writeln('=== 当前财务数据 ===');
    buf.writeln('当前时间: $todayStr');
    buf.writeln('本月: $monthPrefix');
    buf.writeln();

    // Monthly overview
    final monthTxs = provider.transactions
        .where((t) => t.date.startsWith(monthPrefix))
        .toList();
    final monthExpense =
        monthTxs.where((t) => t.type == 0).fold<int>(0, (s, t) => s + t.amount);
    final monthIncome =
        monthTxs.where((t) => t.type == 1).fold<int>(0, (s, t) => s + t.amount);
    final balance = monthIncome - monthExpense;

    buf.writeln('**本月概况:**');
    buf.writeln('- 总支出: ${currencyFormat.format(monthExpense / 100)}');
    buf.writeln('- 总收入: ${currencyFormat.format(monthIncome / 100)}');
    buf.writeln(
        '- 结余: ${currencyFormat.format(balance / 100)}');
    buf.writeln();

    // Category breakdown (top 5)
    final catTotals = <String, int>{};
    for (final t in monthTxs.where((t) => t.type == 0)) {
      catTotals[t.categoryId] =
          (catTotals[t.categoryId] ?? 0) + t.amount;
    }
    final sortedCats = catTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (sortedCats.isNotEmpty) {
      buf.writeln('**支出分类 Top ${sortedCats.length > 5 ? 5 : sortedCats.length}:**');
      var rank = 1;
      for (final e in sortedCats.take(5)) {
        final cat = provider.getCategoryById(e.key);
        final pct = monthExpense > 0
            ? (e.value / monthExpense * 100).toStringAsFixed(0)
            : '0';
        buf.writeln(
            '$rank. ${cat?.name ?? "未知"}: ${currencyFormat.format(e.value / 100)} ($pct%)');
        rank++;
      }
      buf.writeln();
    }

    // Month-over-month comparison
    final lastMonthTxs = provider.transactions
        .where((t) => t.date.startsWith(lastMonthPrefix))
        .toList();
    final lastMonthExpense = lastMonthTxs
        .where((t) => t.type == 0)
        .fold<int>(0, (s, t) => s + t.amount);
    if (lastMonthExpense > 0) {
      final changePct =
          ((monthExpense - lastMonthExpense) / lastMonthExpense * 100)
              .toStringAsFixed(1);
      buf.writeln('**与上月对比:**');
      buf.writeln(
          '- 上月支出: ${currencyFormat.format(lastMonthExpense / 100)}');
      buf.writeln(
          '- 支出环比: ${changePct.startsWith('-') ? '' : '+'}$changePct%');

      // Top category changes
      for (final e in sortedCats.take(3)) {
        final lastAmt = lastMonthTxs
            .where((t) =>
                t.type == 0 && t.categoryId == e.key)
            .fold<int>(0, (s, t) => s + t.amount);
        if (lastAmt > 0) {
          final cat = provider.getCategoryById(e.key);
          final catChange =
              ((e.value - lastAmt) / lastAmt * 100).toStringAsFixed(0);
          buf.writeln(
              '- ${cat?.name ?? "?"} 环比: ${catChange.startsWith('-') ? '' : '+'}$catChange%');
        }
      }
      buf.writeln();
    }

    // Budget
    final budget = provider.getTotalBudget(monthPrefix);
    if (budget != null && budget.totalAmount > 0) {
      final progress = (monthExpense / budget.totalAmount * 100)
          .toStringAsFixed(1);
      final remainingDays =
          DateTime(now.year, now.month + 1, 0).day - now.day;
      buf.writeln('**预算情况:**');
      buf.writeln(
          '- 月度预算: ${currencyFormat.format(budget.totalAmount / 100)}');
      buf.writeln(
          '- 已使用: ${currencyFormat.format(monthExpense / 100)} ($progress%)');
      buf.writeln('- 剩余天数: $remainingDays 天');
      buf.writeln();
    }

    // Balance sheet
    final accounts = provider.allAccounts;
    final totalAssets = accounts
        .where((a) => a.type != 2 && a.balance > 0)
        .fold<int>(0, (s, a) => s + a.balance);
    final totalLiabilities = accounts
        .where((a) => a.type == 2 || a.balance < 0)
        .fold<int>(0, (s, a) => s + a.balance.abs());
    buf.writeln('**资产负债:**');
    buf.writeln(
        '- 总资产: ${currencyFormat.format(totalAssets / 100)}');
    buf.writeln(
        '- 总负债: ${currencyFormat.format(totalLiabilities / 100)}');
    buf.writeln(
        '- 净资产: ${currencyFormat.format((totalAssets - totalLiabilities) / 100)}');
    buf.writeln();

    // Investments
    if (provider.investments.isNotEmpty) {
      buf.writeln('**投资:**');
      buf.writeln(
          '- 总投资市值: ${currencyFormat.format(provider.totalInvestmentValue / 100)}');
      final pnl = provider.totalInvestmentProfitLoss;
      buf.writeln(
          '- 总盈亏: ${pnl >= 0 ? '+' : ''}${currencyFormat.format(pnl / 100)}');
      buf.writeln();
    }

    // Saving goals
    final activeGoals =
        provider.savingGoals.where((g) => !g.isCompleted).toList();
    if (activeGoals.isNotEmpty) {
      buf.writeln('**存钱计划:**');
      for (final g in activeGoals.take(3)) {
        final pct =
            (g.currentAmount / g.targetAmount * 100).toStringAsFixed(0);
        buf.writeln(
            '- "${g.name}": 进度 $pct% (${currencyFormat.format(g.currentAmount / 100)}/${currencyFormat.format(g.targetAmount / 100)})');
      }
      buf.writeln();
    }

    // Debts
    final activeDebts = provider.debts.where((d) => !d.isSettled).toList();
    if (activeDebts.isNotEmpty) {
      buf.writeln('**债务:**');
      for (final d in activeDebts.take(5)) {
        final typeLabel = d.type == 0 ? '借出给' : '借入自';
        buf.writeln(
            '- $typeLabel${d.personName}: ${currencyFormat.format(d.remainingAmount / 100)} (未还)');
      }
      buf.writeln();
    }

    // Monthly trend (last 6 months)
    final trend = provider.getLast12MonthsTrend();
    if (trend.length > 1) {
      buf.writeln('**近12月趋势:**');
      for (final m in trend.reversed.take(6)) {
        buf.writeln(
            '- ${m.month}: 支出 ${currencyFormat.format(m.expense / 100)}, 收入 ${currencyFormat.format(m.income / 100)}');
      }
    }

    return buf.toString();
  }

  // ==================== Send Message ====================

  Future<String> sendMessage({
    required String question,
    required AIConfig config,
    required String financialContext,
    List<ChatMessage>? history,
  }) async {
    final messages = <Map<String, dynamic>>[
      {
        'role': 'system',
        'content':
            '你是一位专业的个人财务顾问。根据用户的记账数据提供简洁、实用的分析和建议。'
                '回答要求：\n'
                '1. 引用具体数字时使用用户数据中的实际值\n'
                '2. 分析要简洁，分点列出\n'
                '3. 给出可操作的建议\n'
                '4. 不要编造数据，只使用提供的上下文中的数据\n'
                '5. 用中文回答',
      },
      {
        'role': 'user',
        'content': '$financialContext\n\n用户问题: $question',
      },
    ];

    // Insert recent history before current question
    if (history != null && history.isNotEmpty) {
      final historyMsgs = history
          .map((m) => {'role': m.role, 'content': m.content})
          .toList();
      messages.insertAll(1, historyMsgs);
    }

    final response = await http.post(
      Uri.parse('${config.baseUrl}/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${config.apiKey}',
      },
      body: jsonEncode({
        'model': config.model,
        'messages': messages,
        'max_tokens': 1024,
        'temperature': 0.7,
      }),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final choice = data['choices']?[0];
      if (choice != null) {
        return choice['message']['content'] ?? '（无响应内容）';
      }
      return 'AI 未返回有效响应';
    }

    final error = jsonDecode(utf8.decode(response.bodyBytes));
    return '请求失败: ${error['error']?['message'] ?? 'HTTP ${response.statusCode}'}';
  }

  // ==================== Quick Questions ====================

  static const quickQuestions = [
    '本月花了多少钱？哪些支出最高？',
    '和上个月比，哪些支出变化最大？',
    '帮我看看有没有哪些可以省的钱？',
    '我的预算执行情况怎么样？',
    '存钱计划能按时完成吗？',
  ];
}
