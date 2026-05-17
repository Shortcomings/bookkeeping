import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/transaction_provider.dart';
import 'budget_edit_screen.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
    _load();
  }

  Future<void> _load() async {
    final month = _monthStr();
    await context.read<TransactionProvider>().loadBudgets(month);
  }

  String _monthStr() => DateFormat('yyyy-MM').format(_currentMonth);

  void _prevMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
    _load();
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final month = _monthStr();
    final currencyFormat =
        NumberFormat.currency(symbol: '¥', decimalDigits: 2);
    final totalBudget = provider.getTotalBudget(month);
    final progress = provider.getBudgetProgress(month);
    final dailyAvg = provider.getDailyAverageBudget(month);
    final dailySpent = provider.getDailyAverageExpense(month);
    final catBudgets = provider.getCategoryBudgets(month);

    final monthExpense = provider
        .getTransactionsByMonthString(month)
        .where((t) => t.type == 0)
        .fold<int>(0, (s, t) => s + t.amount);

    final now = DateTime.now();
    final daysInMonth = DateTime(
            _currentMonth.year, _currentMonth.month + 1, 0)
        .day;
    final daysLeft = _currentMonth.year == now.year &&
            _currentMonth.month == now.month
        ? (DateTime(_currentMonth.year, _currentMonth.month + 1, 0)
                .difference(now)
                .inDays)
        : daysInMonth;

    return Scaffold(
      appBar: AppBar(
        title: Text('${_currentMonth.year}年${_currentMonth.month}月预算'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider.value(
                  value: provider,
                  child: BudgetEditScreen(month: month),
                ),
              ),
            ).then((_) => _load()),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 月份选择
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                  onPressed: _prevMonth,
                  icon: const Icon(Icons.chevron_left)),
              Text(
                DateFormat('yyyy年M月').format(_currentMonth),
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              IconButton(
                  onPressed: _nextMonth,
                  icon: const Icon(Icons.chevron_right)),
            ],
          ),
          const SizedBox(height: 16),

          // 总预算
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: totalBudget == null
                  ? Column(
                      children: [
                        const Text('本月未设置预算'),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ChangeNotifierProvider.value(
                                value: provider,
                                child:
                                    BudgetEditScreen(month: month),
                              ),
                            ),
                          ).then((_) => _load()),
                          child: const Text('设置预算'),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        Text('总预算',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer
                                        .withAlpha(179))),
                        const SizedBox(height: 4),
                        Text(
                          currencyFormat
                              .format(totalBudget.totalAmount / 100),
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        // 进度条
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress.clamp(0.0, 1.0),
                            minHeight: 8,
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            color: progress < 0.5
                                ? Colors.green
                                : progress < 0.8
                                    ? Colors.orange
                                    : Colors.red,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                                '已花 ${currencyFormat.format(monthExpense / 100)}'),
                            Text(
                                '${(progress * 100).toStringAsFixed(1)}%'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                Text('剩余',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall),
                                Text(
                                  currencyFormat.format(
                                      ((totalBudget.totalAmount -
                                                  monthExpense) /
                                              100)
                                          .clamp(0, double.infinity)),
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .tertiary),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                Text('日均预算',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall),
                                Text(
                                    currencyFormat
                                        .format(dailyAvg / 100),
                                    style: const TextStyle(
                                        fontWeight:
                                            FontWeight.w600)),
                              ],
                            ),
                            Column(
                              children: [
                                Text('日均已花',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall),
                                Text(
                                    currencyFormat
                                        .format(dailySpent / 100),
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: dailySpent > dailyAvg
                                            ? Theme.of(context)
                                                .colorScheme
                                                .error
                                            : Theme.of(context)
                                                .colorScheme
                                                .tertiary)),
                              ],
                            ),
                          ],
                        ),
                        if (daysLeft > 0) ...[
                          const SizedBox(height: 8),
                          Text(
                            '剩余 $daysLeft 天 · 日均可用 ${currencyFormat.format(totalBudget.totalAmount > monthExpense ? (totalBudget.totalAmount - monthExpense) ~/ daysLeft / 100 : 0)}',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 20),

          // 分类预算
          if (catBudgets.isNotEmpty) ...[
            Text('分类预算',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...catBudgets.map((b) {
              final cat = provider.getCategoryById(b.categoryId!);
              final spent = provider
                  .getTransactionsByMonthString(month)
                  .where((t) =>
                      t.type == 0 && t.categoryId == b.categoryId)
                  .fold<int>(0, (s, t) => s + t.amount);
              final pct = b.totalAmount > 0
                  ? spent / b.totalAmount
                  : 0.0;
              return Card(
                margin: const EdgeInsets.only(bottom: 6),
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
                            radius: 12,
                            child: Text(
                                cat?.name
                                        .substring(0, 1) ??
                                    '?',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10)),
                          ),
                          const SizedBox(width: 8),
                          Text(cat?.name ?? '未知',
                              style: const TextStyle(
                                  fontSize: 14)),
                          const Spacer(),
                          Text(
                            '${currencyFormat.format(spent / 100)} / ${currencyFormat.format(b.totalAmount / 100)}',
                            style: TextStyle(
                              fontSize: 13,
                              color: pct >= 1
                                  ? Theme.of(context)
                                      .colorScheme
                                      .error
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius:
                            BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: pct.clamp(0.0, 1.0),
                          minHeight: 6,
                          color: pct < 0.5
                              ? Colors.green
                              : pct < 0.8
                                  ? Colors.orange
                                  : Colors.red,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(pct * 100).toStringAsFixed(1)}%',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
