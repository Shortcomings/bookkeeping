import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/transaction_provider.dart';
import 'periodic_edit_screen.dart';

class PeriodicListScreen extends StatelessWidget {
  const PeriodicListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final items = provider.periodicTransactions;
    final currencyFormat =
        NumberFormat.currency(symbol: '¥', decimalDigits: 2);

    return Scaffold(
      appBar: AppBar(title: const Text('周期账单')),
      body: items.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.repeat, size: 64,
                      color: Theme.of(context).colorScheme.outline.withAlpha(100)),
                  const SizedBox(height: 16),
                  Text('还没有周期账单',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.outline)),
                  const SizedBox(height: 8),
                  Text('添加定期账单，如每月房租、每周通勤等',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.outline,
                          fontSize: 12)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final pt = items[index];
                final cat = provider.getCategoryById(pt.categoryId);
                final isExpense = pt.type == 0;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: cat != null
                                  ? Color(int.parse(cat.color))
                                  : Colors.grey,
                              radius: 16,
                              child: Text(
                                  cat?.name.substring(0, 1) ??
                                      '?',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(cat?.name ?? '未知',
                                      style: const TextStyle(fontSize: 14)),
                                  if (pt.note != null &&
                                      pt.note!.isNotEmpty)
                                    Text(pt.note!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(context).colorScheme.outline)),
                                ],
                              ),
                            ),
                            Text(
                              '${isExpense ? '-' : '+'}${currencyFormat.format(pt.amount / 100)}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isExpense
                                    ? Theme.of(context).colorScheme.error
                                    : Theme.of(context).colorScheme.tertiary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _Badge(
                              label: pt.frequencyLabel,
                              active: true,
                            ),
                            if (pt.isWorkdayOnly) ...[
                              const SizedBox(width: 4),
                              const _Badge(
                                  label: '工作日', active: true),
                            ],
                            const SizedBox(width: 4),
                            _Badge(
                              label: pt.autoConfirm ? '自动' : '手动确认',
                              active: pt.autoConfirm,
                            ),
                            const Spacer(),
                            Text(
                              '下次: ${pt.nextDate}',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.end,
                          children: [
                            Switch(
                              value: pt.isActive,
                              onChanged: (v) => provider.togglePeriodicActive(pt.id, v),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChangeNotifierProvider.value(
                                    value: provider,
                                    child: PeriodicEditScreen(transaction: pt),
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline,
                                  size: 18,
                                  color: Theme.of(context).colorScheme.error),
                              onPressed: () =>
                                  _confirmDelete(context, pt),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider.value(
              value: provider,
              child: const PeriodicEditScreen(),
            ),
          ),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _confirmDelete(BuildContext context, dynamic pt) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除周期账单'),
        content:
            const Text('确定删除吗？已生成的记录不会受影响。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          TextButton(
            onPressed: () {
              context
                  .read<TransactionProvider>()
                  .deletePeriodicTransaction(pt.id);
              Navigator.pop(ctx);
            },
            child: Text('删除',
                style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .error)),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final bool active;
  const _Badge({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: active
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }
}
