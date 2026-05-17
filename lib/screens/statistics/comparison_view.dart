import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/transaction_provider.dart';

class ComparisonView extends StatefulWidget {
  const ComparisonView({super.key});

  @override
  State<ComparisonView> createState() => _ComparisonViewState();
}

class _ComparisonViewState extends State<ComparisonView> {
  late DateTime _currentMonth;
  late int _currentYear;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month);
    _currentYear = now.year;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final currencyFormat =
        NumberFormat.currency(symbol: '¥', decimalDigits: 2);
    final currentStr = DateFormat('yyyy-MM').format(_currentMonth);

    // Previous period
    final prevMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    final prevStr = DateFormat('yyyy-MM').format(prevMonth);

    // Month over month
    final currentExpense = provider
        .getTransactionsByMonthString(currentStr)
        .where((t) => t.type == 0)
        .fold<int>(0, (s, t) => s + t.amount);
    final currentIncome = provider
        .getTransactionsByMonthString(currentStr)
        .where((t) => t.type == 1)
        .fold<int>(0, (s, t) => s + t.amount);
    final prevExpense = provider
        .getTransactionsByMonthString(prevStr)
        .where((t) => t.type == 0)
        .fold<int>(0, (s, t) => s + t.amount);
    final prevIncome = provider
        .getTransactionsByMonthString(prevStr)
        .where((t) => t.type == 1)
        .fold<int>(0, (s, t) => s + t.amount);

    // Year over year
    final currentYearTotal = provider.getYearTotal(0, _currentYear);
    final prevYearTotal = provider.getYearTotal(0, _currentYear - 1);

    // Trend
    final trend = provider.getLast12MonthsTrend();

    // Top 5
    final topChanges =
        provider.getTopCategoryChanges(currentStr, prevStr);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ---- 月度对比 ----
        Text('月度对比',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        // Month selector
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => setState(() {
                    _currentMonth = DateTime(
                        _currentMonth.year, _currentMonth.month - 1);
                  }),
            ),
            Text(
              '${_currentMonth.year}年${_currentMonth.month}月 vs ${prevMonth.year}年${prevMonth.month}月',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => setState(() {
                    _currentMonth = DateTime(
                        _currentMonth.year, _currentMonth.month + 1);
                  }),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _ComparisonCard(
              title: '支出',
              current: currencyFormat.format(currentExpense / 100),
              previous: currencyFormat.format(prevExpense / 100),
              change: _calcChange(currentExpense, prevExpense),
              isExpense: true,
            )),
            const SizedBox(width: 8),
            Expanded(child: _ComparisonCard(
              title: '收入',
              current: currencyFormat.format(currentIncome / 100),
              previous: currencyFormat.format(prevIncome / 100),
              change: _calcChange(currentIncome, prevIncome),
              isExpense: false,
            )),
          ],
        ),
        const SizedBox(height: 20),

        // ---- 年度对比 ----
        Text('年度对比',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () =>
                  setState(() => _currentYear--),
            ),
            Text(
              '$_currentYear vs ${_currentYear - 1}',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () =>
                  setState(() => _currentYear++),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(child: _ComparisonCard(
              title: '${_currentYear}年支出',
              current:
                  currencyFormat.format(currentYearTotal / 100),
              previous: currencyFormat
                  .format(prevYearTotal / 100),
              change:
                  _calcChange(currentYearTotal, prevYearTotal),
              isExpense: true,
            )),
          ],
        ),
        const SizedBox(height: 24),

        // ---- 12月趋势 ----
        Text('近12月趋势',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: _TrendChart(trend: trend),
        ),
        const SizedBox(height: 24),

        // ---- Top 5 变动 ----
        Text('支出 Top 5 变动',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        if (topChanges.isEmpty)
          Text('暂无数据',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.outline))
        else
          ...topChanges.map((c) {
            final cat = provider.getCategoryById(c.categoryId);
            return Card(
              margin: const EdgeInsets.only(bottom: 4),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: cat != null
                      ? Color(int.parse(cat.color))
                      : Colors.grey,
                  radius: 14,
                  child: Text(
                      cat?.name.substring(0, 1) ?? '?',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 11)),
                ),
                title: Text(cat?.name ?? '未知',
                    style: const TextStyle(fontSize: 14)),
                subtitle: Text(
                  '上月: ${currencyFormat.format(c.previousAmount / 100)}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      currencyFormat
                          .format(c.currentAmount / 100),
                      style:
                          const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      c.changePercent >= 0 ? '↑ ${c.changePercent.toStringAsFixed(1)}%' : '↓ ${c.changePercent.abs().toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: c.changePercent >= 0
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.tertiary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  double _calcChange(int current, int previous) {
    if (previous == 0) return current > 0 ? 100 : 0;
    return (current - previous) / previous * 100;
  }
}

class _ComparisonCard extends StatelessWidget {
  final String title;
  final String current;
  final String previous;
  final double change;
  final bool isExpense;

  const _ComparisonCard({
    required this.title,
    required this.current,
    required this.previous,
    required this.change,
    required this.isExpense,
  });

  @override
  Widget build(BuildContext context) {
    final upColor = isExpense
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.tertiary;
    final downColor = isExpense
        ? Theme.of(context).colorScheme.tertiary
        : Theme.of(context).colorScheme.error;
    final changeColor = change >= 0 ? upColor : downColor;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(title, style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 4),
            Text(current,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(previous,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  change >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 14,
                  color: changeColor,
                ),
                Text(
                  '${change.abs().toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 12, color: changeColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  final List<MonthSummary> trend;

  const _TrendChart({required this.trend});

  @override
  Widget build(BuildContext context) {
    if (trend.isEmpty) return const SizedBox();

    final maxVal = trend.fold<double>(
        0,
        (max, s) => s.expense.toDouble() > max
            ? s.expense.toDouble()
            : max);

    return CustomPaint(
      size: const Size(double.infinity, 200),
      painter: _TrendPainter(
        trend: trend,
        maxVal: maxVal,
        expenseColor: Theme.of(context).colorScheme.error,
        incomeColor: Theme.of(context).colorScheme.tertiary,
        textColor: Theme.of(context).colorScheme.outline,
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<MonthSummary> trend;
  final double maxVal;
  final Color expenseColor;
  final Color incomeColor;
  final Color textColor;

  _TrendPainter({
    required this.trend,
    required this.maxVal,
    required this.expenseColor,
    required this.incomeColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (trend.isEmpty || maxVal == 0) return;

    final paint = Paint()..strokeWidth = 2;
    final leftPadding = 40.0;
    final bottomPadding = 20.0;
    final chartWidth = size.width - leftPadding;
    final chartHeight = size.height - bottomPadding - 20;
    final stepX = chartWidth / (trend.length - 1);

    // Draw grid lines
    final gridPaint = Paint()
      ..color = Colors.grey.withAlpha(30)
      ..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final y = 20 + chartHeight * (1 - i / 4);
      canvas.drawLine(
          Offset(leftPadding, y), Offset(size.width, y), gridPaint);
    }

    // Draw expense line
    paint.color = expenseColor;
    for (int i = 0; i < trend.length - 1; i++) {
      final x1 = leftPadding + stepX * i;
      final y1 = 20 + chartHeight * (1 - trend[i].expense / maxVal);
      final x2 = leftPadding + stepX * (i + 1);
      final y2 =
          20 + chartHeight * (1 - trend[i + 1].expense / maxVal);
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
    }

    // Draw income line
    paint.color = incomeColor;
    for (int i = 0; i < trend.length - 1; i++) {
      final x1 = leftPadding + stepX * i;
      final y1 = 20 + chartHeight * (1 - trend[i].income / maxVal);
      final x2 = leftPadding + stepX * (i + 1);
      final y2 =
          20 + chartHeight * (1 - trend[i + 1].income / maxVal);
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
    }

    // Draw labels
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i < trend.length; i++) {
      if (i % 2 == 0) {
        tp.text = TextSpan(
            text: trend[i].month, style: TextStyle(color: textColor, fontSize: 10));
        tp.layout();
        tp.paint(
          canvas,
          Offset(leftPadding + stepX * i - tp.width / 2,
              size.height - bottomPadding + 4),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
