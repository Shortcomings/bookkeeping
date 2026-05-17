import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/transaction_provider.dart';
import 'debt_edit_screen.dart';
import 'debt_repayment_screen.dart';

class DebtListScreen extends StatelessWidget {
  const DebtListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final debts = provider.debts;
    final currencyFormat = NumberFormat.currency(symbol: '¥', decimalDigits: 2);
    final active = debts.where((d) => !d.isSettled).toList();
    final settled = debts.where((d) => d.isSettled).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('债务管理')),
      body: debts.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.handshake, size: 64, color: Theme.of(context).colorScheme.outline.withAlpha(100)),
              const SizedBox(height: 16), const Text('暂无债务记录'),
            ]))
          : ListView(padding: const EdgeInsets.all(16), children: [
              if (active.isNotEmpty) ...[
                Text('未结清 · ${active.length}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ...active.map((d) => _DebtCard(debt: d, currencyFormat: currencyFormat)),
              ],
              if (settled.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('已结清 · ${settled.length}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ...settled.map((d) => _DebtCard(debt: d, currencyFormat: currencyFormat)),
              ],
            ]),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(value: provider, child: const DebtEditScreen()),
        )),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _DebtCard extends StatelessWidget {
  final dynamic debt;
  final NumberFormat currencyFormat;
  const _DebtCard({required this.debt, required this.currencyFormat});

  @override
  Widget build(BuildContext context) {
    final typeLabel = debt.type == 0 ? '我欠别人' : '别人欠我';
    final typeColor = debt.type == 0 ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.tertiary;
    final progress = debt.totalAmount > 0 ? (debt.totalAmount - debt.remainingAmount) / debt.totalAmount : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: !debt.isSettled ? () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(
            value: context.read<TransactionProvider>(),
            child: DebtRepaymentScreen(debt: debt),
          ),
        )) : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: typeColor.withAlpha(20), borderRadius: BorderRadius.circular(4)),
                child: Text(typeLabel, style: TextStyle(color: typeColor, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              Text(debt.personName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const Spacer(),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(currencyFormat.format(debt.remainingAmount / 100),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: typeColor)),
                Text('总额 ${currencyFormat.format(debt.totalAmount / 100)}',
                    style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline)),
              ]),
            ]),
            const SizedBox(height: 6),
            ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(
              value: progress, minHeight: 4, color: typeColor,
            )),
            if (debt.isOverdue) Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('⚠ 已逾期', style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
            if (debt.expectedRepayDate != null && !debt.isOverdue && !debt.isSettled)
              Padding(padding: const EdgeInsets.only(top: 4),
                child: Text('还款日: ${debt.expectedRepayDate}', style: Theme.of(context).textTheme.labelSmall)),
          ]),
        ),
      ),
    );
  }
}
