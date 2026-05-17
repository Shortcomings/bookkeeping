import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/transaction_provider.dart';
import '../../models/transaction.dart';
import '../transaction/add_transaction_sheet.dart';

class HomeScreen extends StatelessWidget {
  final ValueChanged<int>? onTabChange;
  const HomeScreen({super.key, this.onTabChange});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final now = DateTime.now();
    final monthPrefix = DateFormat('yyyy-MM').format(now);
    final todayStr = DateFormat('yyyy-MM-dd').format(now);

    final monthTxs =
        provider.transactions.where((t) => t.date.startsWith(monthPrefix)).toList();
    final todayTxs = monthTxs.where((t) => t.date == todayStr).toList();

    final monthExpense = monthTxs
        .where((t) => t.type == 0)
        .fold<int>(0, (sum, t) => sum + t.amount);
    final monthIncome = monthTxs
        .where((t) => t.type == 1)
        .fold<int>(0, (sum, t) => sum + t.amount);
    final todayExpense = todayTxs
        .where((t) => t.type == 0)
        .fold<int>(0, (sum, t) => sum + t.amount);

    final currencyFormat = NumberFormat.currency(symbol: '¥', decimalDigits: 2);

    return Scaffold(
      appBar: AppBar(
        title: Text('${now.month}月概览'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => onTabChange?.call(1),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: now,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (date != null && context.mounted) {
                onTabChange?.call(1);
              }
            },
          ),
        ],
      ),
      body: provider.loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 月度概览卡片
                _MonthOverviewCard(
                  monthExpense: currencyFormat.format(monthExpense / 100),
                  monthIncome: currencyFormat.format(monthIncome / 100),
                  balance: currencyFormat.format((monthIncome - monthExpense) / 100),
                ),
                const SizedBox(height: 16),

                // 今日概览
                _TodaySummary(
                  todayExpense: currencyFormat.format(todayExpense / 100),
                  todayCount: todayTxs.length,
                ),
                const SizedBox(height: 20),

                // 最近记录
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('最近记录',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    TextButton(
                      onPressed: () => onTabChange?.call(1),
                      child: const Text('查看全部')),
                  ],
                ),
                if (provider.transactions.isEmpty)
                  _EmptyState()
                else
                  ...provider.transactions.take(10).map(
                        (tx) => _TransactionTile(transaction: tx),
                      ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet(
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
        ),
        icon: const Icon(Icons.add),
        label: const Text('记一笔'),
      ),
    );
  }
}

class _MonthOverviewCard extends StatelessWidget {
  final String monthExpense;
  final String monthIncome;
  final String balance;

  const _MonthOverviewCard({
    required this.monthExpense,
    required this.monthIncome,
    required this.balance,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text('本月支出',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onPrimaryContainer
                        .withAlpha(179))),
            const SizedBox(height: 4),
            Text(monthExpense,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(label: '收入', value: monthIncome,
                    color: Theme.of(context).colorScheme.tertiary),
                _StatItem(label: '结余', value: balance,
                    color: Theme.of(context).colorScheme.primary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onPrimaryContainer
                    .withAlpha(179))),
        const SizedBox(height: 4),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}

class _TodaySummary extends StatelessWidget {
  final String todayExpense;
  final int todayCount;

  const _TodaySummary({required this.todayExpense, required this.todayCount});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.today, size: 20),
            const SizedBox(width: 12),
            Text('今日支出', style: Theme.of(context).textTheme.bodyMedium),
            const Spacer(),
            Text(todayExpense,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(width: 16),
            Text('$todayCount 笔',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final Transaction transaction;

  const _TransactionTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<TransactionProvider>();
    final category = provider.getCategoryById(transaction.categoryId);
    final isExpense = transaction.type == 0;
    final amount =
        NumberFormat.currency(symbol: '¥', decimalDigits: 2).format(
      transaction.amount / 100,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: category != null
              ? Color(int.parse(category.color))
              : Colors.grey,
          radius: 20,
          child: Text(
            category?.name.substring(0, 1) ?? '?',
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
        title: Text(category?.name ?? '未知分类'),
        subtitle: Text(
          transaction.note ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          '${isExpense ? '-' : '+'}$amount',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isExpense
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.tertiary,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.outline.withAlpha(100)),
            const SizedBox(height: 16),
            Text('还没有记录',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.outline)),
            const SizedBox(height: 8),
            Text('点击右下角按钮记第一笔账吧',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline)),
          ],
        ),
      ),
    );
  }
}
