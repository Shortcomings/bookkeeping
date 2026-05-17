import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/transaction_provider.dart';

class ReimbursementListScreen extends StatelessWidget {
  const ReimbursementListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final txs = provider.reimbursableTransactions;
    final currencyFormat = NumberFormat.currency(symbol: '¥', decimalDigits: 2);
    final pending = txs.where((t) => t.reimbursementStatus == 1).toList();
    final submitted = txs.where((t) => t.reimbursementStatus == 2).toList();
    final reimbursed = txs.where((t) => t.reimbursementStatus == 3).toList();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('报销管理'),
          bottom: const TabBar(tabs: [
            Tab(text: '待报销'),
            Tab(text: '已提交'),
            Tab(text: '已报销'),
          ]),
        ),
        body: txs.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.receipt_long, size: 64,
                    color: Theme.of(context).colorScheme.outline.withAlpha(100)),
                const SizedBox(height: 16),
                const Text('暂无报销记录'),
                const SizedBox(height: 8),
                Text('在账单列表左滑可标记为报销',
                    style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12)),
              ]))
            : TabBarView(children: [
                _ReimbursementList(txs: pending, currencyFormat: currencyFormat),
                _ReimbursementList(txs: submitted, currencyFormat: currencyFormat),
                _ReimbursementList(txs: reimbursed, currencyFormat: currencyFormat, showComplete: true),
              ]),
      ),
    );
  }
}

class _ReimbursementList extends StatelessWidget {
  final List<dynamic> txs;
  final NumberFormat currencyFormat;
  final bool showComplete;
  const _ReimbursementList({required this.txs, required this.currencyFormat, this.showComplete = false});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<TransactionProvider>();
    if (txs.isEmpty) {
      return Center(child: Text('暂无', style: TextStyle(color: Theme.of(context).colorScheme.outline)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: txs.length,
      itemBuilder: (context, index) {
        final tx = txs[index];
        final cat = provider.getCategoryById(tx.categoryId);
        final acc = tx.accountId != null ? provider.getAccountById(tx.accountId!) : null;
        return Card(
          margin: const EdgeInsets.only(bottom: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: cat != null ? Color(int.parse(cat.color)) : Colors.grey,
              radius: 16,
              child: Text(cat?.name.substring(0, 1) ?? '?',
                  style: const TextStyle(color: Colors.white, fontSize: 11)),
            ),
            title: Text(cat?.name ?? '未知'),
            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (tx.note != null) Text(tx.note!, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('${tx.date}${acc != null ? " · ${acc.name}" : ""}',
                  style: const TextStyle(fontSize: 11)),
            ]),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(currencyFormat.format(tx.amount / 100),
                  style: TextStyle(fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.error)),
              if (!showComplete) ...[
                const SizedBox(width: 4),
                PopupMenuButton<int>(
                  onSelected: (status) {
                    if (status == 3) {
                      provider.completeReimbursement(tx.id);
                    } else {
                      provider.updateReimbursementStatus(tx.id, status);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 1, child: Text('待报销')),
                    const PopupMenuItem(value: 2, child: Text('已提交')),
                    const PopupMenuItem(value: 3, child: Text('确认报销到账')),
                  ],
                ),
              ],
            ]),
          ),
        );
      },
    );
  }
}
