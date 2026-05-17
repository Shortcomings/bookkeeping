import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/transaction_provider.dart';
import '../../models/saving_goal.dart';

class SavingEditScreen extends StatefulWidget {
  final SavingGoal? goal;
  const SavingEditScreen({super.key, this.goal});

  @override
  State<SavingEditScreen> createState() => _SavingEditScreenState();
}

class _SavingEditScreenState extends State<SavingEditScreen> {
  late String _name, _amount, _deadline;
  bool _saving = false;
  bool get _isEditing => widget.goal != null;

  @override
  void initState() {
    super.initState();
    final g = widget.goal;
    _name = g?.name ?? '';
    _amount = g != null ? (g.targetAmount / 100).toStringAsFixed(0) : '';
    _deadline = g?.deadline ?? '';
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amount);
    if (amount == null || amount <= 0 || _name.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写完整信息')));
      return;
    }
    setState(() => _saving = true);
    final provider = context.read<TransactionProvider>();
    try {
      if (_isEditing) {
        await provider.updateSavingGoal(widget.goal!.copyWith(
          name: _name.trim(), targetAmount: (amount * 100).round(),
          deadline: _deadline.isEmpty ? null : _deadline,
        ));
      } else {
        await provider.addSavingGoal(
          name: _name.trim(), targetAmount: (amount * 100).round(),
          deadline: _deadline.isEmpty ? null : _deadline,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? '编辑目标' : '新建目标')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(
          decoration: const InputDecoration(labelText: '目标名称', border: OutlineInputBorder()),
          controller: TextEditingController(text: _name),
          onChanged: (v) => _name = v,
        ),
        const SizedBox(height: 12),
        TextField(
          decoration: const InputDecoration(labelText: '目标金额', prefixText: '¥ ', border: OutlineInputBorder()),
          keyboardType: TextInputType.number,
          controller: TextEditingController(text: _amount),
          onChanged: (v) => _amount = v,
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () async {
            final d = await showDatePicker(context: context,
                initialDate: DateTime.now().add(const Duration(days: 90)),
                firstDate: DateTime.now(), lastDate: DateTime(2100));
            if (d != null) setState(() => _deadline = DateFormat('yyyy-MM-dd').format(d));
          },
          child: InputDecorator(
            decoration: const InputDecoration(labelText: '截止日期 (可选)', border: OutlineInputBorder()),
            child: Text(_deadline.isEmpty ? '无截止日期' : _deadline),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
          child: _saving ? const SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(_isEditing ? '保存' : '创建目标')),
      ]),
    );
  }
}
