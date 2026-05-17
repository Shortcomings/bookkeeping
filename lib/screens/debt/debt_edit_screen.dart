import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/transaction_provider.dart';
import '../../models/debt.dart';

class DebtEditScreen extends StatefulWidget {
  final Debt? debt;
  const DebtEditScreen({super.key, this.debt});

  @override
  State<DebtEditScreen> createState() => _DebtEditScreenState();
}

class _DebtEditScreenState extends State<DebtEditScreen> {
  int _type = 0;
  String _personName = '';
  String _amount = '';
  String _date = '';
  String _expectedRepayDate = '';
  String _note = '';
  bool _saving = false;
  bool get _isEditing => widget.debt != null;

  @override
  void initState() {
    super.initState();
    _date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final d = widget.debt;
    if (d != null) {
      _type = d.type; _personName = d.personName;
      _amount = (d.totalAmount / 100).toStringAsFixed(2);
      _date = d.date;
      _expectedRepayDate = d.expectedRepayDate ?? '';
      _note = d.note ?? '';
    }
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amount);
    if (amount == null || amount <= 0 || _personName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请填写完整信息')));
      return;
    }
    setState(() => _saving = true);
    final provider = context.read<TransactionProvider>();
    try {
      if (_isEditing) {
        final newTotal = (amount * 100).round();
        final oldRemaining = widget.debt!.remainingAmount;
        final oldTotal = widget.debt!.totalAmount;
        final newRemaining = newTotal == oldTotal
            ? oldRemaining
            : (oldRemaining / oldTotal * newTotal).round();
        await provider.updateDebt(widget.debt!.copyWith(
          type: _type, personName: _personName.trim(),
          totalAmount: newTotal,
          remainingAmount: newRemaining,
          date: _date,
          expectedRepayDate: _expectedRepayDate.isEmpty ? null : _expectedRepayDate,
          note: _note.isEmpty ? null : _note,
        ));
      } else {
        await provider.addDebt(
          type: _type, personName: _personName.trim(),
          amount: (amount * 100).round(), date: _date,
          expectedRepayDate: _expectedRepayDate.isEmpty ? null : _expectedRepayDate,
          note: _note.isEmpty ? null : _note,
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
      appBar: AppBar(title: Text(_isEditing ? '编辑债务' : '添加债务')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          ChoiceChip(label: const Text('我欠别人'), selected: _type == 0,
            onSelected: (_) => setState(() => _type = 0),
            selectedColor: Theme.of(context).colorScheme.error.withAlpha(30)),
          const SizedBox(width: 8),
          ChoiceChip(label: const Text('别人欠我'), selected: _type == 1,
            onSelected: (_) => setState(() => _type = 1),
            selectedColor: Theme.of(context).colorScheme.tertiary.withAlpha(30)),
        ]),
        const SizedBox(height: 16),
        TextField(
          decoration: const InputDecoration(labelText: '人员姓名', border: OutlineInputBorder()),
          controller: TextEditingController(text: _personName),
          onChanged: (v) => _personName = v,
        ),
        const SizedBox(height: 12),
        TextField(
          decoration: const InputDecoration(labelText: '金额', prefixText: '¥ ', border: OutlineInputBorder()),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          controller: TextEditingController(text: _amount),
          onChanged: (v) => _amount = v,
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _DateField(label: '借款日期', value: _date,
            onTap: () async {
              final d = await showDatePicker(context: context,
                  initialDate: DateTime.tryParse(_date) ?? DateTime.now(),
                  firstDate: DateTime(2000), lastDate: DateTime(2100));
              if (d != null) setState(() => _date = DateFormat('yyyy-MM-dd').format(d));
            })),
          const SizedBox(width: 8),
          Expanded(child: _DateField(label: '预期还款', value: _expectedRepayDate,
            onTap: () async {
              final d = await showDatePicker(context: context,
                  initialDate: DateTime.now().add(const Duration(days: 30)),
                  firstDate: DateTime(2000), lastDate: DateTime(2100));
              if (d != null) setState(() => _expectedRepayDate = DateFormat('yyyy-MM-dd').format(d));
            })),
        ]),
        const SizedBox(height: 12),
        TextField(
          decoration: const InputDecoration(labelText: '备注', border: OutlineInputBorder()),
          controller: TextEditingController(text: _note),
          onChanged: (v) => _note = v,
        ),
        const SizedBox(height: 24),
        FilledButton(onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
          child: _saving ? const SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(_isEditing ? '保存' : '添加')),
      ]),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label, value;
  final VoidCallback onTap;
  const _DateField({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        child: Text(value.isEmpty ? '未设置' : value),
      ),
    );
  }
}
