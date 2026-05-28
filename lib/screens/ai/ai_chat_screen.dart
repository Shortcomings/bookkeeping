import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import '../../providers/transaction_provider.dart';
import '../../services/ai_chat_service.dart';
import 'ai_settings_screen.dart';

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final _service = AIChatService();
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  AIConfig? _config;
  ChatSession? _currentSession;
  List<ChatSession> _sessions = [];
  List<ChatMessage> _messages = [];
  bool _loading = false;
  bool _showQuickQuestions = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final config = await _service.loadConfig();
    if (!mounted) return;
    if (!config.isConfigured) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const AISettingsScreen(),
        ),
      );
      return;
    }
    setState(() => _config = config);

    final sessions = await _service.loadSessions();
    if (sessions.isEmpty) {
      final session = await _service.createSession();
      _sessions = [session];
      _currentSession = session;
    } else {
      _sessions = sessions;
      _currentSession = sessions.first;
      final msgs = await _service.loadMessages(_currentSession!.id);
      _messages = msgs;
      _showQuickQuestions = msgs.isEmpty;
    }
    setState(() {});
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _config == null || _loading) return;

    final question = text.trim();
    _inputController.clear();
    setState(() {
      _showQuickQuestions = false;
      _loading = true;
    });

    // Save user message
    final userMsg = await _service.addMessage(
      sessionId: _currentSession!.id,
      role: 'user',
      content: question,
    );
    setState(() => _messages.add(userMsg));
    _scrollToBottom();

    // Auto-title if first message
    if (_currentSession!.title == '新对话') {
      final title = question.length > 15
          ? '${question.substring(0, 15)}...'
          : question;
      await _service.updateSessionTitle(_currentSession!.id, title);
    }

    if (!mounted) return;

    // Build context and send
    final provider = context.read<TransactionProvider>();
    final contextData = _service.buildFinancialContext(provider);
    final response = await _service.sendMessage(
      question: question,
      config: _config!,
      financialContext: contextData,
      history: _messages,
    );

    // Save assistant message
    final assistantMsg = await _service.addMessage(
      sessionId: _currentSession!.id,
      role: 'assistant',
      content: response,
    );
    setState(() {
      _messages.add(assistantMsg);
      _loading = false;
    });
    _scrollToBottom();
  }

  Future<void> _newSession() async {
    final session = await _service.createSession();
    setState(() {
      _currentSession = session;
      _messages = [];
      _showQuickQuestions = true;
      _sessions.insert(0, session);
    });
  }

  Future<void> _switchSession(ChatSession session) async {
    final msgs = await _service.loadMessages(session.id);
    setState(() {
      _currentSession = session;
      _messages = msgs;
      _showQuickQuestions = msgs.isEmpty;
    });
  }

  Future<void> _deleteSession(ChatSession session) async {
    await _service.deleteSession(session.id);
    _sessions.removeWhere((s) => s.id == session.id);
    if (_currentSession?.id == session.id) {
      if (_sessions.isNotEmpty) {
        await _switchSession(_sessions.first);
      } else {
        // Create new default session
        final newSession = await _service.createSession();
        _sessions = [newSession];
        _currentSession = newSession;
        _messages = [];
        _showQuickQuestions = true;
      }
    }
    setState(() {});
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_config == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('AI 财务助手')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentSession?.title ?? 'AI 财务助手'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: '新对话',
            onPressed: _newSession,
          ),
          if (_sessions.length > 1)
            PopupMenuButton<ChatSession>(
              tooltip: '历史对话',
              onSelected: _switchSession,
              itemBuilder: (ctx) => [
                ..._sessions.map(
                  (s) => PopupMenuItem<ChatSession>(
                    value: s,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            s.title,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (s.id == _currentSession?.id)
                          const Icon(Icons.check, size: 16),
                        if (_sessions.length > 1)
                          GestureDetector(
                            onTap: () {
                              Navigator.pop(ctx);
                              _deleteSession(s);
                            },
                            child: const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Icon(Icons.delete_outline,
                                  size: 18, color: Colors.red),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '设置',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AISettingsScreen(),
                ),
              );
              final config = await _service.loadConfig();
              if (mounted) setState(() => _config = config);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: _showQuickQuestions && _messages.isEmpty
                ? _buildWelcome()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    itemCount: _messages.length + (_loading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        return _TypingIndicator();
                      }
                      return _MessageBubble(message: _messages[index]);
                    },
                  ),
          ),

          // Quick questions
          if (_showQuickQuestions && _messages.isEmpty) ...[
            _buildQuickQuestions(),
          ],

          // Input
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildWelcome() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withAlpha(150)),
          const SizedBox(height: 16),
          Text('AI 财务助手',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('我可以帮你分析收支、比较趋势、给出省钱建议',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildQuickQuestions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: AIChatService.quickQuestions.map((q) {
          return ActionChip(
            avatar: const Icon(Icons.auto_awesome, size: 14),
            label: Text(q, style: const TextStyle(fontSize: 12)),
            onPressed: () => _sendMessage(q),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                enabled: !_loading,
                decoration: InputDecoration(
                  hintText: '输入你的财务问题...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  filled: true,
                  fillColor: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withAlpha(80),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: _sendMessage,
              ),
            ),
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _loading
                  ? const SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : IconButton.filled(
                      key: const ValueKey('send'),
                      onPressed:
                          _inputController.text.trim().isEmpty
                              ? null
                              : () => _sendMessage(_inputController.text),
                      icon: const Icon(Icons.send, size: 20),
                      style: IconButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final time =
        DateFormat('HH:mm').format(DateTime.parse(message.createdAt));

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor:
                  Theme.of(context).colorScheme.primaryContainer,
              child: Icon(Icons.auto_awesome,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth:
                    MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUser
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12).copyWith(
                  topLeft: isUser ? const Radius.circular(12) : Radius.zero,
                  topRight:
                      isUser ? Radius.zero : const Radius.circular(12),
                ),
              ),
              child: Column(
                crossAxisAlignment:
                    isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (isUser)
                    Text(message.content,
                        style: Theme.of(context).textTheme.bodyMedium)
                  else
                    MarkdownBody(
                      data: message.content,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet(
                        p: Theme.of(context).textTheme.bodyMedium,
                        h1: Theme.of(context).textTheme.titleLarge,
                        h2: Theme.of(context).textTheme.titleMedium,
                        h3: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                        listBullet: Theme.of(context).textTheme.bodyMedium,
                        code: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    time,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withAlpha(150),
                        ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              child: const Icon(Icons.person, size: 16),
            ),
          ],
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor:
              Theme.of(context).colorScheme.primaryContainer,
          child: Icon(Icons.auto_awesome,
              size: 16,
              color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(12),
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
          ),
          child: const SizedBox(
            width: 40,
            height: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Dot(delay: 0),
                SizedBox(width: 4),
                _Dot(delay: 200),
                SizedBox(width: 4),
                _Dot(delay: 400),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) {
        final delay = widget.delay / 1000.0;
        final value = ((_controller.value - delay) % 1.0).clamp(0.0, 1.0);
        final opacity = (value * 2).clamp(0.0, 1.0);
        return Opacity(
          opacity: opacity,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outline,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
