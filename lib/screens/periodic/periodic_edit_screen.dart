import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/transaction_provider.dart';
import '../../models/periodic_transaction.dart';

class PeriodicEditScreen extends StatefulWidget {
  final PeriodicTransaction? transaction;
  const PeriodicEditScreen({super.key, this.transaction});

  @override
  State<PeriodicEditScreen> createState() => _PeriodicEditScreenState();
}

class _PeriodicEditScreenState extends State<PeriodicEditScreen> {
  int _type = 0;
  String _amount = '';
  String _categoryId = '';
  String? _accountId;
  String _note = '';
  int _frequency = 2; // monthly
  int _customDays = 1;
  bool _isWorkdayOnly = false;
  bool _autoConfirm = true;
  bool _saving = false;

  bool get _isEditing => widget.transaction != null;

  static const _freqLabels = ['每天', '每周', '每月', '每年', '自定义'];

  @override
  void initState() {
    super.initState();
    final p = widget.transaction;
    if (p != null) {
      _type = p.type;
      _amount = (p.amount / 100).toStringAsFixed(2);
      _categoryId = p.categoryId;
      _accountId = p.accountId;
      _note = p.note ?? '';
      _frequency = p.frequency;
      _customDays = p.customDays ?? 1;
      _isWorkdayOnly = p.isWorkdayOnly;
      _autoConfirm = p.autoConfirm;
    }
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amount);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效金额')),
      );
      return;
    }
    if (_categoryId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择分类')),
      );
      return;
    }

    setState(() => _saving = true);
    final provider = context.read<TransactionProvider>();
    final amountInCents = (amount * 100).round();

    try {
      if (_isEditing) {
        await provider.updatePeriodicTransaction(
          widget.transaction!.copyWith(
            type: _type,
            amount: amountInCents,
            categoryId: _categoryId,
            accountId: _accountId,
            note: _note.isEmpty ? null : _note,
            frequency: _frequency,
            customDays: _frequency == 4 ? _customDays : null,
            isWorkdayOnly: _isWorkdayOnly,
            autoConfirm: _autoConfirm,
          ),
        );
      } else {
        await provider.addPeriodicTransaction(
          type: _type,
          amount: amountInCents,
          categoryId: _categoryId,
          accountId: _accountId,
          note: _note.isEmpty ? null : _note,
          frequency: _frequency,
          customDays: _frequency == 4 ? _customDays : null,
          isWorkdayOnly: _isWorkdayOnly,
          autoConfirm: _autoConfirm,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final cats = _type == 0
        ? provider.expenseCategories
        : provider.incomeCategories;
    final accounts = provider.accounts;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑周期账单' : '添加周期账单'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 类型
          Row(
            children: [
              ChoiceChip(
                label: const Text('支出'),
                selected: _type == 0,
                onSelected: (_) => setState(() {
                  _type = 0;
                  _categoryId = provider.expenseCategories.isNotEmpty
                      ? provider.expenseCategories.first.id
                      : '';
                }),
                selectedColor: Theme.of(context).colorScheme.error.withAlpha(30),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('收入'),
                selected: _type == 1,
                onSelected: (_) => setState(() {
                  _type = 1;
                  _categoryId = provider.incomeCategories.isNotEmpty
                      ? provider.incomeCategories.first.id
                      : '';
                }),
                selectedColor: Theme.of(context).colorScheme.tertiary.withAlpha(30),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 金额
          TextField(
            decoration: const InputDecoration(
              labelText: '金额',
              prefixText: '¥ ',
              border: OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            controller: TextEditingController(text: _amount),
            onChanged: (v) => _amount = v,
          ),
          const SizedBox(height: 16),

          // 分类
          Text('分类', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: cats.map((c) {
              final selected = c.id == _categoryId;
              return ChoiceChip(
                label: Text(c.name),
                selected: selected,
                onSelected: (_) => setState(() => _categoryId = c.id),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // 周期
          Text('周期', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: List.generate(5, (i) {
              return ChoiceChip(
                label: Text(_freqLabels[i]),
                selected: _frequency == i,
                onSelected: (_) =>
                    setState(() => _frequency = i),
              );
            }),
          ),
          if (_frequency == 4) ...[
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                labelText: '自定义天数',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              controller: TextEditingController(text: _customDays.toString()),
              onChanged: (v) =>
                  _customDays = int.tryParse(v) ?? 1,
            ),
          ],
          const SizedBox(height: 12),

          // 选项
          SwitchListTile(
            title: const Text('仅工作日'),
            subtitle: const Text('跳过周六和周日'),
            value: _isWorkdayOnly,
            onChanged: (v) =>
                setState(() => _isWorkdayOnly = v),
            dense: true,
          ),
          SwitchListTile(
            title: const Text('自动确认'),
            subtitle: const Text('到期自动生成记录；关闭后需手动确认'),
            value: _autoConfirm,
            onChanged: (v) =>
                setState(() => _autoConfirm = v),
            dense: true,
          ),
          const SizedBox(height: 8),

          // 账户
          if (accounts.isNotEmpty)
            DropdownButtonFormField<String?>(
              initialValue: _accountId,
              decoration: const InputDecoration(
                labelText: '账户（可选）',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('不选择')),
                ...accounts.map((a) => DropdownMenuItem(
                    value: a.id, child: Text(a.name))),
              ],
              onChanged: (v) =>
                  setState(() => _accountId = v),
            ),
          const SizedBox(height: 12),

          // 备注
          TextField(
            decoration: const InputDecoration(
              labelText: '备注',
              border: OutlineInputBorder(),
            ),
            controller: TextEditingController(text: _note),
            onChanged: (v) => _note = v,
            maxLength: 200,
          ),
          const SizedBox(height: 24),

          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
            child: _saving
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(_isEditing ? '保存修改' : '添加周期账单'),
          ),
        ],
      ),
    );
  }
}
