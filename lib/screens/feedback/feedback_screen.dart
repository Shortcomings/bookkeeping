import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/feedback_item.dart';
import '../../services/feedback_service.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _service = FeedbackService();
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _userNameCtrl = TextEditingController();
  int _type = 0;
  bool _loading = false;
  bool _syncing = false;
  bool _hasToken = false;
  List<FeedbackItem> _history = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = await _service.getToken();
    final history = await _service.getHistory();
    final savedName = await _service.getDefaultUserName();
    if (_userNameCtrl.text.isEmpty && savedName.isNotEmpty) {
      _userNameCtrl.text = savedName;
    }
    setState(() {
      _hasToken = token.isNotEmpty;
      _history = history;
    });
  }

  Future<void> _syncAll() async {
    setState(() => _syncing = true);
    for (final item in _history) {
      await _service.checkIssueState(item);
    }
    await _load();
    setState(() => _syncing = false);
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入标题')),
      );
      return;
    }

    // Remember username
    final userName = _userNameCtrl.text.trim();
    if (userName.isNotEmpty) {
      await _service.saveDefaultUserName(userName);
    }

    setState(() => _loading = true);
    final error = await _service.submitFeedback(
      title: _titleCtrl.text.trim(),
      content: _contentCtrl.text.trim(),
      type: _type,
      userName: userName,
    );
    setState(() => _loading = false);

    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    } else {
      _titleCtrl.clear();
      _contentCtrl.clear();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('反馈已提交'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _viewReplies(FeedbackItem item) async {
    showDialog(
      context: context,
      builder: (ctx) => _ReplyDialog(service: _service, item: item),
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _userNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('意见反馈'),
        actions: [
          if (_history.any((h) => h.issueNumber != null))
            IconButton(
              icon: _syncing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.sync),
              tooltip: '同步状态',
              onPressed: _syncing ? null : _syncAll,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _syncAll,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!_hasToken) _buildTokenPrompt(),
            _buildForm(),
            const SizedBox(height: 24),
            if (_history.isNotEmpty) ...[
              Text('反馈历史', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('下拉同步状态，点击查看回复',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
              const SizedBox(height: 8),
              ..._history.map(_buildHistoryItem),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTokenPrompt() {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer.withAlpha(60),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 20),
            SizedBox(width: 12),
            Expanded(child: Text('请在「推送与反馈设置」中配置 GitHub Token')),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('提交反馈', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            TextField(
              controller: _userNameCtrl,
              decoration: const InputDecoration(
                labelText: '用户名',
                hintText: '你的名字（用于标识反馈者）',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('建议')),
                ButtonSegment(value: 1, label: Text('Bug')),
                ButtonSegment(value: 2, label: Text('其他')),
              ],
              selected: {_type},
              onSelectionChanged: (v) => setState(() => _type = v.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: '标题',
                hintText: '一句话描述你的想法或问题',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contentCtrl,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: '详细描述',
                hintText: '请尽量详细地描述...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loading ? null : _submit,
                icon: _loading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send),
                label: Text(_loading ? '提交中...' : '提交反馈'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(FeedbackItem item) {
    final typeColors = {0: Colors.blue, 1: Colors.red, 2: Colors.grey};
    final date = DateFormat('MM/dd HH:mm').format(DateTime.parse(item.createdAt));
    final isClosed = item.issueState == 'closed';
    final hasIssue = item.issueNumber != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: (typeColors[item.type] ?? Colors.grey).withAlpha(30),
          child: Text(item.typeLabel,
              style: TextStyle(fontSize: 11, color: typeColors[item.type], fontWeight: FontWeight.w600)),
        ),
        title: Row(
          children: [
            if (item.userName.isNotEmpty) ...[
              Text('${item.userName}  ',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
            ],
            Expanded(child: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
            if (hasIssue) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: isClosed ? Colors.green.withAlpha(20) : Colors.orange.withAlpha(20),
                ),
                child: Text(
                  isClosed ? '已处理' : '待处理',
                  style: TextStyle(fontSize: 10, color: isClosed ? Colors.green : Colors.orange, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
        subtitle: Row(
          children: [
            Text(date, style: const TextStyle(fontSize: 12)),
            if (hasIssue) ...[
              const Text(' · ', style: TextStyle(fontSize: 12)),
              Text('#${item.issueNumber}', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary)),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasIssue)
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline, size: 20),
                tooltip: '查看回复',
                onPressed: () => _viewReplies(item),
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () async {
                await _service.deleteFeedback(item.id);
                await _load();
              },
            ),
          ],
        ),
        onTap: hasIssue ? () => _viewReplies(item) : null,
      ),
    );
  }
}

class _ReplyDialog extends StatefulWidget {
  final FeedbackService service;
  final FeedbackItem item;

  const _ReplyDialog({required this.service, required this.item});

  @override
  State<_ReplyDialog> createState() => _ReplyDialogState();
}

class _ReplyDialogState extends State<_ReplyDialog> {
  List<FeedbackReply> _replies = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final replies = await widget.service.fetchReplies(widget.item);
    if (mounted) {
      setState(() {
        _replies = replies;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(widget.item.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
          if (widget.item.issueNumber != null)
            Text('#${widget.item.issueNumber}', style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.primary)),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(80),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('${widget.item.userName} 的反馈',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(widget.item.content.isNotEmpty ? widget.item.content : '(无详细描述)',
                      style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('开发者回复', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (_replies.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('暂无回复', style: TextStyle(color: Colors.grey)),
              )
            else
              ..._replies.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.withAlpha(10),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.withAlpha(40)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.reply, size: 14, color: Colors.green),
                              const SizedBox(width: 4),
                              Text(r.author, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              const Spacer(),
                              Text(DateFormat('MM/dd HH:mm').format(DateTime.parse(r.createdAt)),
                                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(r.body, style: const TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                  )),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('刷新'),
          onPressed: () {
            setState(() => _loading = true);
            _fetch();
          },
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
