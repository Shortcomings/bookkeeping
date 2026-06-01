import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static DatabaseHelper? _instance;
  static Database? _database;

  DatabaseHelper._();

  factory DatabaseHelper() {
    _instance ??= DatabaseHelper._();
    return _instance!;
  }

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'bookkeeping.db');
    return openDatabase(
      path,
      version: 8,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 8) {
      try { await db.execute("ALTER TABLE feedback ADD COLUMN user_name TEXT NOT NULL DEFAULT ''"); } catch (_) {}
      try { await db.execute("ALTER TABLE push_config ADD COLUMN default_user_name TEXT NOT NULL DEFAULT ''"); } catch (_) {}
    }
    if (oldVersion < 7) {
      try { await db.execute("ALTER TABLE feedback ADD COLUMN issue_number INTEGER"); } catch (_) {}
      try { await db.execute("ALTER TABLE feedback ADD COLUMN issue_state TEXT NOT NULL DEFAULT 'open'"); } catch (_) {}
      try { await db.execute("UPDATE push_config SET feedback_key='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' WHERE feedback_key=''"); } catch (_) {}
    }
    if (oldVersion < 6) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS feedback (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          content TEXT NOT NULL,
          type INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL
        )
      ''');
      try {
        await db.execute("ALTER TABLE push_config ADD COLUMN feedback_key TEXT NOT NULL DEFAULT ''");
      } catch (_) {}
    }
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS push_config (
          id INTEGER PRIMARY KEY DEFAULT 1,
          provider TEXT NOT NULL DEFAULT 'serverchan',
          push_key TEXT NOT NULL DEFAULT '',
          daily_summary_enabled INTEGER NOT NULL DEFAULT 0,
          budget_alert_enabled INTEGER NOT NULL DEFAULT 0,
          budget_alert_pct INTEGER NOT NULL DEFAULT 80,
          last_daily_push_date TEXT,
          last_budget_alert_date TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS shared_members (
          id TEXT PRIMARY KEY,
          book_id TEXT NOT NULL,
          name TEXT NOT NULL,
          role INTEGER NOT NULL DEFAULT 2,
          joined_at TEXT NOT NULL,
          FOREIGN KEY (book_id) REFERENCES books(id)
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS shared_invitations (
          id TEXT PRIMARY KEY,
          book_id TEXT NOT NULL,
          code TEXT NOT NULL UNIQUE,
          role INTEGER NOT NULL DEFAULT 2,
          is_active INTEGER NOT NULL DEFAULT 1,
          created_at TEXT NOT NULL,
          expires_at TEXT,
          FOREIGN KEY (book_id) REFERENCES books(id)
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS shared_audit_log (
          id TEXT PRIMARY KEY,
          book_id TEXT NOT NULL,
          member_name TEXT NOT NULL,
          action TEXT NOT NULL,
          target_type TEXT,
          target_id TEXT,
          detail TEXT,
          created_at TEXT NOT NULL,
          FOREIGN KEY (book_id) REFERENCES books(id)
        )
      ''');
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN created_by TEXT');
      } catch (_) {}
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ai_config (
          id INTEGER PRIMARY KEY DEFAULT 1,
          provider TEXT NOT NULL DEFAULT 'deepseek',
          api_key TEXT NOT NULL DEFAULT '',
          base_url TEXT NOT NULL DEFAULT 'https://api.deepseek.com/v1',
          model TEXT NOT NULL DEFAULT 'deepseek-chat',
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS chat_sessions (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL DEFAULT '新对话',
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS chat_messages (
          id TEXT PRIMARY KEY,
          session_id TEXT NOT NULL,
          role TEXT NOT NULL,
          content TEXT NOT NULL,
          created_at TEXT NOT NULL,
          FOREIGN KEY (session_id) REFERENCES chat_sessions(id) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS investments (
          id TEXT PRIMARY KEY,
          account_id TEXT NOT NULL,
          name TEXT NOT NULL,
          code TEXT,
          type INTEGER NOT NULL DEFAULT 0,
          shares INTEGER NOT NULL DEFAULT 0,
          cost_basis INTEGER NOT NULL DEFAULT 0,
          current_value INTEGER NOT NULL DEFAULT 0,
          currency TEXT NOT NULL DEFAULT 'CNY',
          note TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (account_id) REFERENCES accounts(id)
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS investment_trades (
          id TEXT PRIMARY KEY,
          investment_id TEXT NOT NULL,
          type INTEGER NOT NULL DEFAULT 0,
          shares INTEGER NOT NULL DEFAULT 0,
          price INTEGER NOT NULL DEFAULT 0,
          amount INTEGER NOT NULL,
          date TEXT NOT NULL,
          note TEXT,
          created_at TEXT NOT NULL,
          FOREIGN KEY (investment_id) REFERENCES investments(id)
        )
      ''');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type INTEGER NOT NULL DEFAULT 0,
        icon TEXT NOT NULL DEFAULT '0xe3c8',
        color TEXT NOT NULL DEFAULT '0xFF5C6BC0',
        parent_id TEXT,
        is_enabled INTEGER NOT NULL DEFAULT 1,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE accounts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type INTEGER NOT NULL DEFAULT 0,
        balance INTEGER NOT NULL DEFAULT 0,
        currency TEXT NOT NULL DEFAULT 'CNY',
        icon TEXT NOT NULL DEFAULT '0xe3c8',
        color TEXT NOT NULL DEFAULT '0xFF5C6BC0',
        credit_limit INTEGER,
        bill_date INTEGER,
        due_date INTEGER,
        is_enabled INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        type INTEGER NOT NULL DEFAULT 0,
        amount INTEGER NOT NULL,
        date TEXT NOT NULL,
        category_id TEXT NOT NULL,
        account_id TEXT,
        book_id TEXT NOT NULL DEFAULT 'default',
        note TEXT,
        tags TEXT,
        is_refund INTEGER NOT NULL DEFAULT 0,
        refund_transaction_id TEXT,
        is_reimbursed INTEGER NOT NULL DEFAULT 0,
        reimbursement_status INTEGER NOT NULL DEFAULT 0,
        is_periodic INTEGER NOT NULL DEFAULT 0,
        periodic_id TEXT,
        created_by TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories(id),
        FOREIGN KEY (account_id) REFERENCES accounts(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE budgets (
        id TEXT PRIMARY KEY,
        month TEXT NOT NULL,
        total_amount INTEGER NOT NULL,
        category_id TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE books (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        icon TEXT NOT NULL DEFAULT '0xe3c8',
        color TEXT NOT NULL DEFAULT '0xFF5C6BC0',
        type INTEGER NOT NULL DEFAULT 0,
        is_shared INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE debts (
        id TEXT PRIMARY KEY,
        type INTEGER NOT NULL DEFAULT 0,
        person_name TEXT NOT NULL,
        total_amount INTEGER NOT NULL,
        remaining_amount INTEGER NOT NULL,
        date TEXT NOT NULL,
        expected_repay_date TEXT,
        note TEXT,
        is_settled INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE debt_repayments (
        id TEXT PRIMARY KEY,
        debt_id TEXT NOT NULL,
        amount INTEGER NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (debt_id) REFERENCES debts(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE saving_goals (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        target_amount INTEGER NOT NULL,
        current_amount INTEGER NOT NULL DEFAULT 0,
        deadline TEXT,
        cover_image TEXT,
        is_completed INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE periodic_transactions (
        id TEXT PRIMARY KEY,
        type INTEGER NOT NULL DEFAULT 0,
        amount INTEGER NOT NULL,
        category_id TEXT NOT NULL,
        account_id TEXT,
        book_id TEXT NOT NULL DEFAULT 'default',
        note TEXT,
        frequency INTEGER NOT NULL DEFAULT 2,
        custom_days INTEGER,
        is_workday_only INTEGER NOT NULL DEFAULT 0,
        next_date TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        auto_confirm INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE investments (
        id TEXT PRIMARY KEY,
        account_id TEXT NOT NULL,
        name TEXT NOT NULL,
        code TEXT,
        type INTEGER NOT NULL DEFAULT 0,
        shares INTEGER NOT NULL DEFAULT 0,
        cost_basis INTEGER NOT NULL DEFAULT 0,
        current_value INTEGER NOT NULL DEFAULT 0,
        currency TEXT NOT NULL DEFAULT 'CNY',
        note TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (account_id) REFERENCES accounts(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE investment_trades (
        id TEXT PRIMARY KEY,
        investment_id TEXT NOT NULL,
        type INTEGER NOT NULL DEFAULT 0,
        shares INTEGER NOT NULL DEFAULT 0,
        price INTEGER NOT NULL DEFAULT 0,
        amount INTEGER NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (investment_id) REFERENCES investments(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE ai_config (
        id INTEGER PRIMARY KEY DEFAULT 1,
        provider TEXT NOT NULL DEFAULT 'deepseek',
        api_key TEXT NOT NULL DEFAULT '',
        base_url TEXT NOT NULL DEFAULT 'https://api.deepseek.com/v1',
        model TEXT NOT NULL DEFAULT 'deepseek-chat',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE chat_sessions (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL DEFAULT '新对话',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE chat_messages (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (session_id) REFERENCES chat_sessions(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE shared_members (
        id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL,
        name TEXT NOT NULL,
        role INTEGER NOT NULL DEFAULT 2,
        joined_at TEXT NOT NULL,
        FOREIGN KEY (book_id) REFERENCES books(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE shared_invitations (
        id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL,
        code TEXT NOT NULL UNIQUE,
        role INTEGER NOT NULL DEFAULT 2,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        expires_at TEXT,
        FOREIGN KEY (book_id) REFERENCES books(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE shared_audit_log (
        id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL,
        member_name TEXT NOT NULL,
        action TEXT NOT NULL,
        target_type TEXT,
        target_id TEXT,
        detail TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (book_id) REFERENCES books(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS push_config (
        id INTEGER PRIMARY KEY DEFAULT 1,
        provider TEXT NOT NULL DEFAULT 'serverchan',
        push_key TEXT NOT NULL DEFAULT '',
        daily_summary_enabled INTEGER NOT NULL DEFAULT 0,
        budget_alert_enabled INTEGER NOT NULL DEFAULT 0,
        budget_alert_pct INTEGER NOT NULL DEFAULT 80,
        last_daily_push_date TEXT,
        last_budget_alert_date TEXT,
        feedback_key TEXT NOT NULL DEFAULT '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',
        default_user_name TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS feedback (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        type INTEGER NOT NULL DEFAULT 0,
        user_name TEXT NOT NULL DEFAULT '',
        issue_number INTEGER,
        issue_state TEXT NOT NULL DEFAULT 'open',
        created_at TEXT NOT NULL
      )
    ''');

    await _insertDefaultData(db);
  }

  Future<void> _insertDefaultData(Database db) async {
    final now = DateTime.now().toIso8601String();

    // 默认支出分类
    final expenseCategories = [
      {'name': '餐饮', 'icon': '0xe532', 'color': '0xFFFF7043', 'type': 0},
      {'name': '交通', 'icon': '0xe530', 'color': '0xFF42A5F5', 'type': 0},
      {'name': '购物', 'icon': '0xe8b8', 'color': '0xFFAB47BC', 'type': 0},
      {'name': '娱乐', 'icon': '0xe40c', 'color': '0xFFFFA726', 'type': 0},
      {'name': '居住', 'icon': '0xe0af', 'color': '0xFF78909C', 'type': 0},
      {'name': '医疗', 'icon': '0xe3f2', 'color': '0xFFEF5350', 'type': 0},
      {'name': '教育', 'icon': '0xe80e', 'color': '0xFF66BB6A', 'type': 0},
      {'name': '通讯', 'icon': '0xe0cf', 'color': '0xFF29B6F6', 'type': 0},
      {'name': '日用', 'icon': '0xe1b4', 'color': '0xFF8D6E63', 'type': 0},
      {'name': '人情', 'icon': '0xe7fd', 'color': '0xFFEC407A', 'type': 0},
      {'name': '其他', 'icon': '0xe5d3', 'color': '0xFFBDBDBD', 'type': 0},
    ];

    for (var i = 0; i < expenseCategories.length; i++) {
      final c = expenseCategories[i];
      await db.insert('categories', {
        'id': 'exp_$i',
        'name': c['name'],
        'type': c['type'],
        'icon': c['icon'],
        'color': c['color'],
        'parent_id': null,
        'is_enabled': 1,
        'sort_order': i,
        'created_at': now,
        'updated_at': now,
      });
    }

    // 默认收入分类
    final incomeCategories = [
      {'name': '工资', 'icon': '0xe263', 'color': '0xFF43A047', 'type': 1},
      {'name': '奖金', 'icon': '0xe598', 'color': '0xFF7CB342', 'type': 1},
      {'name': '投资', 'icon': '0xe227', 'color': '0xFF0097A7', 'type': 1},
      {'name': '兼职', 'icon': '0xe1db', 'color': '0xFF26A69A', 'type': 1},
      {'name': '退款', 'icon': '0xe040', 'color': '0xFF5C6BC0', 'type': 1},
      {'name': '其他', 'icon': '0xe5d3', 'color': '0xFFBDBDBD', 'type': 1},
    ];

    for (var i = 0; i < incomeCategories.length; i++) {
      final c = incomeCategories[i];
      await db.insert('categories', {
        'id': 'inc_$i',
        'name': c['name'],
        'type': c['type'],
        'icon': c['icon'],
        'color': c['color'],
        'parent_id': null,
        'is_enabled': 1,
        'sort_order': i,
        'created_at': now,
        'updated_at': now,
      });
    }

    // 默认账户
    final accounts = [
      {'name': '现金', 'type': 0, 'icon': '0xe3cb'},
      {'name': '借记卡', 'type': 1, 'icon': '0xe870'},
      {'name': '支付宝', 'type': 3, 'icon': '0xe862'},
      {'name': '微信', 'type': 3, 'icon': '0xe0e1'},
    ];

    for (var i = 0; i < accounts.length; i++) {
      final a = accounts[i];
      await db.insert('accounts', {
        'id': 'acc_$i',
        'name': a['name'],
        'type': a['type'],
        'balance': 0,
        'currency': 'CNY',
        'icon': a['icon'],
        'color': '0xFF5C6BC0',
        'is_enabled': 1,
        'created_at': now,
        'updated_at': now,
      });
    }

    // 默认账本
    await db.insert('books', {
      'id': 'default',
      'name': '日常账本',
      'icon': '0xe3cb',
      'color': '0xFF5C6BC0',
      'type': 0,
      'is_shared': 0,
      'created_at': now,
      'updated_at': now,
    });
  }
}
