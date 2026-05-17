import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/transaction_provider.dart';
import 'saving_edit_screen.dart';

class SavingListScreen extends StatelessWidget {
  const SavingListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final goals = provider.savingGoals;
    final currencyFormat = NumberFormat.currency(symbol: '¥', decimalDigits: 2);
    final active = goals.where((g) => !g.isCompleted).toList();
    final done = goals.where((g) => g.isCompleted).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('存钱计划')),
      body: goals.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.savings, size: 64, color: Theme.of(context).colorScheme.outline.withAlpha(100)),
              const SizedBox(height: 16), const Text('还没有存钱目标'),
            ]))
          : ListView(padding: const EdgeInsets.all(16), children: [
              if (active.isNotEmpty) ...[
                Text('进行中 · ${active.length}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ...active.map((g) => _GoalCard(goal: g, currencyFormat: currencyFormat)),
              ],
              if (done.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('已完成 · ${done.length}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ...done.map((g) => _GoalCard(goal: g, currencyFormat: currencyFormat)),
              ],
            ]),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(value: provider, child: const SavingEditScreen()),
        )),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final dynamic goal;
  final NumberFormat currencyFormat;
  const _GoalCard({required this.goal, required this.currencyFormat});

  @override
  Widget build(BuildContext context) {
    final pct = goal.progress as double;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showActions(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.flag, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(goal.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
              Text(currencyFormat.format(goal.currentAmount / 100)),
              Text(' / ${currencyFormat.format(goal.targetAmount / 100)}',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
            ]),
            const SizedBox(height: 8),
            ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0), minHeight: 10,
              color: goal.isCompleted ? Colors.green : pct < 0.5 ? Colors.orange : Colors.lightGreen,
            )),
            const SizedBox(height: 4),
            Row(children: [
              Text('${(pct * 100).toStringAsFixed(1)}%', style: Theme.of(context).textTheme.labelSmall),
              const Spacer(),
              if (!goal.isCompleted) ...[
                Text('还需 ${currencyFormat.format(goal.remaining / 100)}',
                    style: Theme.of(context).textTheme.labelSmall),
                if (goal.daysLeft != null) ...[
                  const Text(' · '),
                  Text('${goal.daysLeft}天',
                      style: TextStyle(color: goal.daysLeft! < 30 ? Theme.of(context).colorScheme.error : null, fontSize: 11)),
                ],
              ],
            ]),
          ]),
        ),
      ),
    );
  }

  void _showActions(BuildContext context) {
    final provider = context.read<TransactionProvider>();
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(goal.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextField(
                controller: ctrl,
                decoration: const InputDecoration(prefixText: '¥ ', hintText: '存入金额', border: OutlineInputBorder(), isDense: true),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () {
                final amount = double.tryParse(ctrl.text);
                if (amount != null && amount > 0) {
                  provider.addSavingAmount(goal.id, (amount * 100).round());
                  Navigator.pop(ctx);
                }
              },
              child: const Text('存入'),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            TextButton.icon(
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('编辑'),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ChangeNotifierProvider.value(value: provider, child: SavingEditScreen(goal: goal)),
                ));
              },
            ),
            TextButton.icon(
              icon: Icon(Icons.delete_outline, size: 16, color: Theme.of(context).colorScheme.error),
              label: Text('删除', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onPressed: () {
                Navigator.pop(ctx);
                provider.deleteSavingGoal(goal.id);
              },
            ),
          ]),
        ]),
      ),
    );
  }
}
