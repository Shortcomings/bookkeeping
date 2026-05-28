import 'package:flutter/material.dart';
import '../../services/ai_chat_service.dart';

class AISettingsScreen extends StatefulWidget {
  const AISettingsScreen({super.key});

  @override
  State<AISettingsScreen> createState() => _AISettingsScreenState();
}

class _AISettingsScreenState extends State<AISettingsScreen> {
  final _service = AIChatService();
  final _keyController = TextEditingController();
  final _urlController = TextEditingController();
  final _modelController = TextEditingController();

  int _providerIndex = 0;
  String? _testResult;
  bool _testing = false;
  bool _saving = false;
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = await _service.loadConfig();
    final idx = aiProviders.indexWhere((p) => p.name == config.provider);
    _providerIndex = idx != -1 ? idx : 0;
    _keyController.text = config.apiKey;
    _urlController.text = config.baseUrl;
    _modelController.text = config.model;
    setState(() {});
  }

  void _onProviderChanged(int index) {
    final provider = aiProviders[index];
    setState(() {
      _providerIndex = index;
      _urlController.text = provider.baseUrl;
      _modelController.text = provider.defaultModel;
    });
  }

  Future<void> _testConnection() async {
    final config = _buildConfig();
    if (config.apiKey.isEmpty) {
      setState(() => _testResult = '请先填写 API Key');
      return;
    }

    setState(() {
      _testing = true;
      _testResult = null;
    });

    final result = await _service.testConnection(config);
    if (mounted) {
      setState(() {
        _testing = false;
        _testResult = result;
      });
    }
  }

  Future<void> _save() async {
    final config = _buildConfig();
    if (config.apiKey.isEmpty) {
      setState(() => _testResult = '请填写 API Key');
      return;
    }

    setState(() => _saving = true);
    await _service.saveConfig(config);
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('配置已保存')),
      );
      Navigator.pop(context, true);
    }
  }

  AIConfig _buildConfig() {
    final provider = aiProviders[_providerIndex];
    return AIConfig(
      provider: provider.name,
      apiKey: _keyController.text.trim(),
      baseUrl: _urlController.text.trim(),
      model: _modelController.text.trim(),
    );
  }

  @override
  void dispose() {
    _keyController.dispose();
    _urlController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 助手设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Provider selector
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('服务商', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: _providerIndex,
                    items: List.generate(
                      aiProviders.length,
                      (i) => DropdownMenuItem(
                        value: i,
                        child: Text(aiProviders[i].name),
                      ),
                    ),
                    onChanged: (v) {
                      if (v != null) _onProviderChanged(v);
                    },
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // API Key
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('API Key', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _keyController,
                    obscureText: _obscureKey,
                    decoration: InputDecoration(
                      hintText: '粘贴你的 API Key',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureKey
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () =>
                            setState(() => _obscureKey = !_obscureKey),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Key 仅保存在本地，不会上传到任何第三方服务器',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Base URL & Model
          if (_providerIndex == aiProviders.length - 1) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('API 地址',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _urlController,
                      decoration: const InputDecoration(
                        hintText: 'https://api.example.com/v1',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
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
                    Text('模型名称',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _modelController,
                      decoration: const InputDecoration(
                        hintText: 'gpt-4o-mini',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Model selector for preset providers
          if (_providerIndex < aiProviders.length - 1) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('模型', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                    initialValue: aiProviders[_providerIndex]
                              .models
                              .contains(_modelController.text)
                          ? _modelController.text
                          : aiProviders[_providerIndex].defaultModel,
                      items: aiProviders[_providerIndex]
                          .models
                          .map((m) => DropdownMenuItem(
                                value: m,
                                child: Text(m),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _modelController.text = v);
                        }
                      },
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Test result
          if (_testResult != null) ...[
            Card(
              color: _testResult == '连接成功'
                  ? Colors.green.withAlpha(20)
                  : Colors.orange.withAlpha(20),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      _testResult == '连接成功'
                          ? Icons.check_circle
                          : Icons.error_outline,
                      color: _testResult == '连接成功'
                          ? Colors.green
                          : Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_testResult!,
                          style: TextStyle(
                            color: _testResult == '连接成功'
                                ? Colors.green.shade800
                                : Colors.orange.shade800,
                            fontSize: 13,
                          )),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _testing ? null : _testConnection,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                  child: _testing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('连接测试'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('保存配置'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
