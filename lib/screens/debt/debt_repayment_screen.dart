import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/transaction_provider.dart';
import '../../models/debt.dart';

class DebtRepaymentScreen extends StatefulWidget {
  final Debt debt;
  const DebtRepaymentScreen({super.key, required this.debt});

  @override
  State<DebtRepaymentScreen> createState() => _DebtRepaymentScreenState();
}

class _DebtRepaymentScreenState extends State<DebtRepaymentScreen> {
  String _amount = '';
  String _date = '';
  String _note = '';

  @override
  void initState() {
    super.initState();
    _date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _amount = (widget.debt.remainingAmount / 100).toStringAsFixed(2);
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amount);
    if (amount == null || amount <= 0 || amount * 100 > widget.debt.remainingAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('金额无效或超过剩余欠款')));
      return;
    }
    await context.read<TransactionProvider>().addDebtRepayment(
      debtId: widget.debt.id, amount: (amount * 100).round(),
      date: _date, note: _note.isEmpty ? null : _note,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final repayments = provider.getRepayments(widget.debt.id);
    final currencyFormat = NumberFormat.currency(symbol: '¥', decimalDigits: 2);

    return Scaffold(
      appBar: AppBar(title: Text('${widget.debt.personName} - 还款')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
            Text('剩余: ${currencyFormat.format(widget.debt.remainingAmount / 100)}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('总额: ${currencyFormat.format(widget.debt.totalAmount / 100)}'),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: widget.debt.totalAmount > 0
                  ? (widget.debt.totalAmount - widget.debt.remainingAmount) / widget.debt.totalAmount
                  : 0,
              minHeight: 6,
            ),
          ])),
        ),
        const SizedBox(height: 16),
        Text('添加还款', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          decoration: const InputDecoration(labelText: '还款金额', prefixText: '¥ ', border: OutlineInputBorder()),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          controller: TextEditingController(text: _amount),
          onChanged: (v) => _amount = v,
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: InkWell(
            onTap: () async {
              final d = await showDatePicker(context: context,
                  initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
              if (d != null) setState(() => _date = DateFormat('yyyy-MM-dd').format(d));
            },
            child: InputDecorator(
              decoration: const InputDecoration(labelText: '还款日期', border: OutlineInputBorder()),
              child: Text(_date),
            ),
          )),
        ]),
        const SizedBox(height: 8),
        TextField(
          decoration: const InputDecoration(labelText: '备注', border: OutlineInputBorder()),
          onChanged: (v) => _note = v,
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: _save,
          child: Text('确认还款 ${currencyFormat.format((double.tryParse(_amount) ?? 0))}')),
        const SizedBox(height: 20),
        if (repayments.isNotEmpty) ...[
          Text('还款记录', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...repayments.map((r) => ListTile(
            title: Text(currencyFormat.format(r.amount / 100)),
            subtitle: Text(r.date),
            trailing: r.note != null ? Text(r.note!) : null,
          )),
        ],
      ]),
    );
  }
}
