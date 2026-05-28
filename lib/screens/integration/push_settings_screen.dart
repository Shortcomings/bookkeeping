import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/transaction_provider.dart';
import '../../services/push_service.dart';

class PushSettingsScreen extends StatefulWidget {
  const PushSettingsScreen({super.key});

  @override
  State<PushSettingsScreen> createState() => _PushSettingsScreenState();
}

class _PushSettingsScreenState extends State<PushSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  String _provider = 'serverchan';
  final _keyController = TextEditingController();
  bool _dailySummaryEnabled = false;
  bool _budgetAlertEnabled = false;
  int _budgetAlertPct = 80;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = await PushService().getConfig();
    _provider = config.provider;
    _keyController.text = config.pushKey;
    _dailySummaryEnabled = config.dailySummaryEnabled;
    _budgetAlertEnabled = config.budgetAlertEnabled;
    _budgetAlertPct = config.budgetAlertPct;
    setState(() {});
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    await PushService().saveConfig(PushConfig(
      provider: _provider,
      pushKey: _keyController.text.trim(),
      dailySummaryEnabled: _dailySummaryEnabled,
      budgetAlertEnabled: _budgetAlertEnabled,
      budgetAlertPct: _budgetAlertPct,
    ));
    setState(() => _loading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('配置已保存')),
      );
    }
  }

  Future<void> _testPush() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    final result = await PushService().testPush(PushConfig(
      provider: _provider,
      pushKey: _keyController.text.trim(),
    ));
    setState(() => _loading = false);

    if (mounted) {
      final isSuccess = result == 'success';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isSuccess ? '测试推送发送成功，请检查微信' : result),
          backgroundColor: isSuccess ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _pushDailySummary() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<TransactionProvider>();

    final formConfig = PushConfig(
      provider: _provider,
      pushKey: _keyController.text.trim(),
      dailySummaryEnabled: true,
      budgetAlertEnabled: _budgetAlertEnabled,
      budgetAlertPct: _budgetAlertPct,
    );

    setState(() => _loading = true);
    final result = await PushService().sendDailySummary(provider, configOverride: formConfig);
    setState(() => _loading = false);

    if (mounted) {
      final isSuccess = result == 'success';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isSuccess ? '日报已推送到微信' : result),
          backgroundColor: isSuccess ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('微信推送设置')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('推送服务商', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'serverchan', label: Text('Server酱')),
                        ButtonSegment(value: 'pushplus', label: Text('PushPlus')),
                      ],
                      selected: {_provider},
                      onSelectionChanged: (v) => setState(() => _provider = v.first),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('获取 Key', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(
                      _provider == 'serverchan'
                          ? '关注"方糖"公众号 → 注册账号 → 获取 SendKey'
                          : '关注"PushPlus"公众号 → 获取 Token',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _keyController,
                      decoration: InputDecoration(
                        labelText: _provider == 'serverchan' ? 'SendKey' : 'Token',
                        hintText: '请输入推送 Key',
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? '请输入 Key' : null,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('每日消费总结'),
                    subtitle: const Text('每天早上打开App时推送昨日消费报告'),
                    value: _dailySummaryEnabled,
                    onChanged: (v) => setState(() => _dailySummaryEnabled = v),
                  ),
                  const Divider(height: 1, indent: 16),
                  SwitchListTile(
                    title: const Text('预算超限提醒'),
                    subtitle: const Text('当月支出超过预算设定值后推送告警'),
                    value: _budgetAlertEnabled,
                    onChanged: (v) => setState(() => _budgetAlertEnabled = v),
                  ),
                  if (_budgetAlertEnabled) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          const Text('告警阈值：'),
                          DropdownButton<int>(
                            value: _budgetAlertPct,
                            items: [80, 90, 100].map((p) => DropdownMenuItem(
                              value: p,
                              child: Text('$p%'),
                            )).toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _budgetAlertPct = v);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.send),
                      title: const Text('测试推送'),
                      subtitle: const Text('发送一条测试消息到微信'),
                      trailing: _loading
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.chevron_right),
                      onTap: _loading ? null : _testPush,
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: const Icon(Icons.today),
                      title: const Text('手动推送日报'),
                      subtitle: const Text('立即推送昨日消费总结'),
                      trailing: _loading
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.chevron_right),
                      onTap: _loading ? null : _pushDailySummary,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '定时推送将在您打开App时自动执行，无需保持后台运行。',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loading ? null : _save,
              icon: const Icon(Icons.save),
              label: const Text('保存配置'),
            ),
          ],
        ),
      ),
    );
  }
}
