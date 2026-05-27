import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/transaction_provider.dart';

class JoinBookScreen extends StatefulWidget {
  const JoinBookScreen({super.key});

  @override
  State<JoinBookScreen> createState() => _JoinBookScreenState();
}

class _JoinBookScreenState extends State<JoinBookScreen> {
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _joining = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    final name = _nameCtrl.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入邀请码')));
      return;
    }
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入你的名称')));
      return;
    }
    setState(() => _joining = true);
    final error = await context.read<TransactionProvider>().joinByInviteCode(code, name);
    if (mounted) {
      setState(() => _joining = false);
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('加入成功！')));
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('加入共享账本')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.group_add, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            '输入邀请码加入他人的共享账本',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _codeCtrl,
            decoration: const InputDecoration(
              labelText: '邀请码',
              hintText: '输入6位邀请码',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.vpn_key),
            ),
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            style: const TextStyle(fontSize: 18, letterSpacing: 4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: '你的名称',
              hintText: '在共享账本中显示的名称',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: _joining ? null : _join,
              child: _joining
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('加入账本'),
            ),
          ),
        ],
      ),
    );
  }
}
