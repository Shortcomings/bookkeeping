import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/transaction_provider.dart';

class CreditCardScreen extends StatelessWidget {
  const CreditCardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final cards = provider.allAccounts.where((a) => a.type == 2).toList();
    final currencyFormat = NumberFormat.currency(symbol: '¥', decimalDigits: 2);

    return Scaffold(
      appBar: AppBar(title: const Text('信用卡管理')),
      body: cards.isEmpty
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.credit_card, size: 64,
                    color: Theme.of(context).colorScheme.outline.withAlpha(100)),
                const SizedBox(height: 16),
                const Text('暂无信用卡'),
                const SizedBox(height: 8),
                Text('在「资产」页面添加信用卡账户',
                    style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12)),
              ]))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: cards.map((card) {
                final used = card.balance < 0 ? -card.balance : 0;
                final limit = card.creditLimit ?? 1;
                final usage = limit > 0 ? used / limit : 0.0;
                final today = DateTime.now();
                // Calculate days until bill/due date
                int? daysToBill, daysToDue;
                if (card.billDate != null) {
                  var billDay = DateTime(today.year, today.month, card.billDate!);
                  if (billDay.isBefore(today)) billDay = DateTime(today.year, today.month + 1, card.billDate!);
                  daysToBill = billDay.difference(today).inDays;
                }
                if (card.dueDate != null) {
                  var dueDay = DateTime(today.year, today.month, card.dueDate!);
                  if (dueDay.isBefore(today)) dueDay = DateTime(today.year, today.month + 1, card.dueDate!);
                  daysToDue = dueDay.difference(today).inDays;
                }
                // Interest-free days
                int? freeDays;
                if (card.billDate != null && card.dueDate != null) {
                  freeDays = (card.dueDate! - card.billDate!).clamp(0, 56);
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        CircleAvatar(backgroundColor: Color(int.parse(card.color)), radius: 16,
                          child: Text(card.name.substring(0, 1), style: const TextStyle(color: Colors.white, fontSize: 12))),
                        const SizedBox(width: 10),
                        Text(card.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Text(currencyFormat.format(used / 100), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ]),
                      const SizedBox(height: 4),
                      Text('额度: ${currencyFormat.format(limit / 100)}',
                          style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 13)),
                      const SizedBox(height: 8),
                      ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(
                        value: usage.clamp(0.0, 1.0), minHeight: 8,
                        color: usage < 0.5 ? Colors.green : usage < 0.8 ? Colors.orange : Colors.red,
                      )),
                      const SizedBox(height: 4),
                      Text('已用 ${(usage * 100).toStringAsFixed(1)}%', style: Theme.of(context).textTheme.labelSmall),
                      const SizedBox(height: 8),
                      Row(children: [
                        if (daysToBill != null) _InfoChip(label: '账单日', value: '${card.billDate}号', days: daysToBill),
                        const SizedBox(width: 8),
                        if (daysToDue != null) _InfoChip(label: '还款日', value: '${card.dueDate}号', days: daysToDue, urgent: daysToDue <= 3),
                        const SizedBox(width: 8),
                        if (freeDays != null) _InfoChip(label: '免息期', value: '$freeDays天'),
                      ]),
                    ]),
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final int? days;
  final bool urgent;
  const _InfoChip({required this.label, required this.value, this.days, this.urgent = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: urgent ? Theme.of(context).colorScheme.errorContainer : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(children: [
        Text(label, style: const TextStyle(fontSize: 10)),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
            color: urgent ? Theme.of(context).colorScheme.error : null)),
        if (days != null) Text('${days! > 0 ? "$days天后" : "今天"}', style: const TextStyle(fontSize: 10)),
      ]),
    );
  }
}
