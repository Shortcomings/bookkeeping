import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../models/feedback_item.dart';
import 'push_service.dart';

class FeedbackReply {
  final String author;
  final String body;
  final String createdAt;

  const FeedbackReply({
    required this.author,
    required this.body,
    required this.createdAt,
  });
}

class FeedbackService {
  static final FeedbackService _instance = FeedbackService._();
  factory FeedbackService() => _instance;
  FeedbackService._();

  final _db = DatabaseHelper();
  static const _workerUrl = 'https://bookkeeping-feedback.lzj1156433224.workers.dev';

  Future<String> getToken() async {
    // Token is handled server-side by Cloudflare Worker.
    // Kept for backward compatibility with UI that checks token availability.
    return 'configured';
  }

  /// Submit feedback: create GitHub Issue via Worker + save locally with issue number.
  Future<String?> submitFeedback({
    required String title,
    required String content,
    required int type,
    required String userName,
  }) async {
    final typeLabel = switch (type) { 1 => 'Bug', 2 => '其他', _ => '建议' };
    final userPrefix = userName.isNotEmpty ? '[用户名：$userName] ' : '';
    final issueTitle = '$userPrefix[$typeLabel] $title';

    final issueBody = StringBuffer();
    if (userName.isNotEmpty) {
      issueBody.writeln('**提交者：$userName**');
      issueBody.writeln();
    }
    issueBody.writeln(content);
    issueBody.writeln();
    issueBody.writeln('---');
    issueBody.writeln('> 通过 App 内反馈功能自动提交');
    issueBody.writeln('> 类型：$typeLabel');

    try {
      final response = await http.post(
        Uri.parse('$_workerUrl/issues'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'title': issueTitle,
          'body': issueBody.toString(),
          'labels': ['feedback', typeLabel],
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 201) {
        final issue = jsonDecode(response.body);
        final issueNumber = issue['number'] as int;
        await _saveLocal(
          title: title,
          content: content,
          type: type,
          userName: userName,
          issueNumber: issueNumber,
          issueState: 'open',
        );
        return null;
      }

      final body = jsonDecode(response.body);
      final msg = body['message'] as String? ?? 'HTTP ${response.statusCode}';
      return msg;
    } catch (e) {
      // Offline: save locally without issue number
      await _saveLocal(title: title, content: content, type: type, userName: userName);
      return null;
    }
  }

  Future<void> _saveLocal({
    required String title,
    required String content,
    required int type,
    required String userName,
    int? issueNumber,
    String issueState = 'open',
  }) async {
    final db = await _db.database;
    await db.insert('feedback', {
      'id': const Uuid().v4(),
      'title': title,
      'content': content,
      'type': type,
      'user_name': userName,
      'issue_number': issueNumber,
      'issue_state': issueState,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Get saved default user name.
  Future<String> getDefaultUserName() async {
    final config = await PushService().getConfig();
    return config.defaultUserName;
  }

  /// Save default user name.
  Future<void> saveDefaultUserName(String name) async {
    final config = await PushService().getConfig();
    await PushService().saveConfig(PushConfig(
      provider: config.provider,
      pushKey: config.pushKey,
      feedbackKey: config.feedbackKey,
      defaultUserName: name,
      dailySummaryEnabled: config.dailySummaryEnabled,
      budgetAlertEnabled: config.budgetAlertEnabled,
      budgetAlertPct: config.budgetAlertPct,
      lastDailyPushDate: config.lastDailyPushDate,
      lastBudgetAlertDate: config.lastBudgetAlertDate,
    ));
  }

  Future<List<FeedbackItem>> getHistory() async {
    final db = await _db.database;
    final results = await db.query('feedback', orderBy: 'created_at DESC');
    return results.map((r) => FeedbackItem.fromMap(r)).toList();
  }

  /// Fetch replies for a feedback item from its GitHub issue.
  Future<List<FeedbackReply>> fetchReplies(FeedbackItem item) async {
    if (item.issueNumber == null) return [];

    try {
      final response = await http.get(
        Uri.parse('$_workerUrl/issues/${item.issueNumber}/comments'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final comments = jsonDecode(response.body) as List;
        return comments.map((c) => FeedbackReply(
          author: (c['user']?['login'] as String?) ?? 'unknown',
          body: (c['body'] as String?) ?? '',
          createdAt: (c['created_at'] as String?) ?? '',
        )).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Check and update issue state from GitHub.
  Future<String> checkIssueState(FeedbackItem item) async {
    if (item.issueNumber == null) return item.issueState;

    try {
      final response = await http.get(
        Uri.parse('$_workerUrl/issues/${item.issueNumber}'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final issue = jsonDecode(response.body);
        final state = (issue['state'] as String?) ?? 'open';
        final db = await _db.database;
        await db.update('feedback', {'issue_state': state},
            where: 'id = ?', whereArgs: [item.id]);
        return state;
      }
      return item.issueState;
    } catch (_) {
      return item.issueState;
    }
  }

  Future<void> deleteFeedback(String id) async {
    final db = await _db.database;
    await db.delete('feedback', where: 'id = ?', whereArgs: [id]);
  }
}
