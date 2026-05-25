import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/transaction_provider.dart';
import '../../models/transaction.dart';
import 'add_transaction_sheet.dart';
import '../search/search_screen.dart';

class TransactionListScreen extends StatelessWidget {
  const TransactionListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('账单'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider.value(
                  value: provider,
                  child: const SearchScreen(),
                ),
              ),
            ),
          ),
        ],
      ),
      body: provider.transactions.isEmpty
          ? _EmptyState()
          : RefreshIndicator(
              onRefresh: () => provider.loadTransactions(),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: provider.transactions.length,
                itemBuilder: (context, index) {
                  final tx = provider.transactions[index];
                  final showHeader = index == 0 ||
                      tx.date != provider.transactions[index - 1].date;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showHeader)
                        Padding(
                          padding: const EdgeInsets.only(top: 16, bottom: 8),
                          child: Text(
                            _formatDateHeader(tx.date),
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.outline,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      Dismissible(
                        key: Key(tx.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.error,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.delete,
                              color: Theme.of(context).colorScheme.onError),
                        ),
                        confirmDismiss: (_) => _showDeleteDialog(context, tx.id),
                        child: _TransactionCard(
                          transaction: tx,
                          onTap: () => _showEditSheet(context, tx.id),
                          onLongPress: () => _showActionSheet(context, tx.id, tx.type == 0),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
    );
  }

  String _formatDateHeader(String dateStr) {
    final date = DateTime.tryParse(dateStr);
    if (date == null) return dateStr;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = today.difference(target).inDays;

    if (diff == 0) return '今天';
    if (diff == 1) return '昨天';
    if (diff < 7) return '本周';
    if (target.year == now.year && target.month == now.month) return '本月';
    return DateFormat('yyyy年M月d日').format(date);
  }

  Future<bool?> _showDeleteDialog(BuildContext context, String txId) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除记录'),
        content: const Text('确定要删除这条记录吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              context.read<TransactionProvider>().deleteTransaction(txId);
              Navigator.pop(ctx, true);
            },
            child: Text('删除',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
  }

  void _showActionSheet(BuildContext context, String txId, bool isExpense) {
    final provider = context.read<TransactionProvider>();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (isExpense) ...[
              ListTile(
                leading: const Icon(Icons.money_off),
                title: const Text('退款'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showRefundDialog(context, txId);
                },
              ),
              ListTile(
                leading: const Icon(Icons.receipt_long),
                title: const Text('标记为报销'),
                onTap: () {
                  Navigator.pop(ctx);
                  provider.markReimbursable(txId);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已标记为待报销')));
                },
              ),
            ],
            ListTile(
              leading: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
              title: Text('删除', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () {
                Navigator.pop(ctx);
                _showDeleteDialog(context, txId);
              },
            ),
          ]),
        ),
      ),
    );
  }

  void _showRefundDialog(BuildContext context, String txId) {
    final provider = context.read<TransactionProvider>();
    final tx = provider.transactions.firstWhere((t) => t.id == txId);

    final amountCtrl = TextEditingController(text: (tx.amount / 100).toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退款'),
        content: TextField(
          controller: amountCtrl,
          decoration: const InputDecoration(prefixText: '¥ ', labelText: '退款金额'),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () {
            final a = double.tryParse(amountCtrl.text);
            if (a != null && a > 0) {
              provider.refundTransaction(txId, (a * 100).round());
              Navigator.pop(ctx);
            }
          }, child: const Text('确认退款')),
        ],
      ),
    );
  }

  void _showEditSheet(BuildContext context, String txId) {
    final provider = context.read<TransactionProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: provider,
        child: AddTransactionSheet(editTransactionId: txId),
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _TransactionCard({required this.transaction, required this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<TransactionProvider>();
    final cat = provider.getCategoryById(transaction.categoryId);
    final isExpense = transaction.type == 0;
    final amount = NumberFormat.currency(symbol: '¥', decimalDigits: 2)
        .format(transaction.amount / 100);
    final note = transaction.note;

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor:
                    cat != null ? Color(int.parse(cat.color)) : Colors.grey,
                radius: 18,
                child: Text(
                  cat?.name.substring(0, 1) ?? '?',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cat?.name ?? '未知', style: const TextStyle(fontSize: 15)),
                    if (note != null && note.isNotEmpty)
                      Text(
                        note.length > 20 ? '${note.substring(0, 20)}...' : note,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.outline,
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '${isExpense ? '-' : '+'}$amount',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isExpense
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.tertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline.withAlpha(100)),
          const SizedBox(height: 16),
          Text('还没有账单记录',
              style: TextStyle(color: Theme.of(context).colorScheme.outline)),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () {
              final provider = context.read<TransactionProvider>();
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (_) => ChangeNotifierProvider.value(
                  value: provider,
                  child: const AddTransactionSheet(),
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('记第一笔账'),
          ),
        ],
      ),
    );
  }
}
