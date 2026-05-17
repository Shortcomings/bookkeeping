import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/transaction_provider.dart';
import 'comparison_view.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen>
    with SingleTickerProviderStateMixin {
  int _selectedTab = 0; // 0=week, 1=month, 2=year
  String? _drillDownCategoryId;

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedTab = _tabController.index;
          _drillDownCategoryId = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  (String, String) _dateRange() {
    final now = DateTime.now();
    String start, end;
    if (_selectedTab == 0) {
      final weekday = now.weekday;
      final monday = now.subtract(Duration(days: weekday - 1));
      final sunday = monday.add(const Duration(days: 6));
      start = DateFormat('yyyy-MM-dd').format(monday);
      end = DateFormat('yyyy-MM-dd').format(sunday);
    } else if (_selectedTab == 1) {
      start = DateFormat('yyyy-MM-dd').format(DateTime(now.year, now.month, 1));
      end = DateFormat('yyyy-MM-dd')
          .format(DateTime(now.year, now.month + 1, 0));
    } else if (_selectedTab == 2) {
      start = DateFormat('yyyy-MM-dd').format(DateTime(now.year, 1, 1));
      end = DateFormat('yyyy-MM-dd').format(DateTime(now.year, 12, 31));
    } else {
      start = DateFormat('yyyy-MM-dd').format(now);
      end = start;
    }
    return (start, end);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final (startDate, endDate) = _dateRange();
    final currencyFormat = NumberFormat.currency(symbol: '¥', decimalDigits: 2);

    final filteredTxs = provider.transactions.where((t) =>
        t.date.compareTo(startDate) >= 0 && t.date.compareTo(endDate) <= 0).toList();

    final totalExpense =
        filteredTxs.where((t) => t.type == 0).fold<int>(0, (s, t) => s + t.amount);
    final totalIncome =
        filteredTxs.where((t) => t.type == 1).fold<int>(0, (s, t) => s + t.amount);
    final balance = totalIncome - totalExpense;

    // Category totals for expense
    final catTotals = <String, int>{};
    for (final tx in filteredTxs) {
      if (tx.type == 0) {
        catTotals[tx.categoryId] = (catTotals[tx.categoryId] ?? 0) + tx.amount;
      }
    }

    final sortedCats = catTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final pieSections = <PieChartSectionData>[];
    final colors = [
      const Color(0xFFFF7043),
      const Color(0xFF42A5F5),
      const Color(0xFFAB47BC),
      const Color(0xFFFFA726),
      const Color(0xFF78909C),
      const Color(0xFFEF5350),
      const Color(0xFF66BB6A),
      const Color(0xFF29B6F6),
      const Color(0xFF8D6E63),
      const Color(0xFFEC407A),
    ];

    int colorIndex = 0;
    for (final entry in sortedCats) {
      final cat = provider.getCategoryById(entry.key);
      final catColor = cat != null ? Color(int.parse(cat.color)) : colors[colorIndex % colors.length];
      final percent = totalExpense > 0 ? entry.value / totalExpense * 100 : 0.0;
      pieSections.add(PieChartSectionData(
        value: entry.value.toDouble(),
        title: percent >= 5 ? '${percent.toStringAsFixed(0)}%' : '',
        color: catColor,
        radius: 55,
        titleStyle: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ));
      colorIndex++;
    }

    final tabLabels = ['本周', '本月', '本年', '对比'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('统计'),
        bottom: TabBar(
          controller: _tabController,
          tabs: tabLabels.map((l) => Tab(text: l)).toList(),
        ),
      ),
      body: _selectedTab == 3
          ? const ComparisonView()
          : filteredTxs.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.pie_chart_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.outline.withAlpha(100)),
                  const SizedBox(height: 16),
                  Text('${tabLabels[_selectedTab]}暂无数据',
                      style: TextStyle(color: Theme.of(context).colorScheme.outline)),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Overview card
                Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text('${tabLabels[_selectedTab]}支出',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer
                                    .withAlpha(179))),
                        const SizedBox(height: 4),
                        Text(
                          currencyFormat.format(totalExpense / 100),
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.error),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _StatItem(
                              label: '收入',
                              value: currencyFormat.format(totalIncome / 100),
                              color: Theme.of(context).colorScheme.tertiary,
                            ),
                            _StatItem(
                              label: '结余',
                              value: currencyFormat.format(balance / 100),
                              color: balance >= 0
                                  ? Theme.of(context).colorScheme.tertiary
                                  : Theme.of(context).colorScheme.error,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Pie chart
                if (pieSections.isNotEmpty && _drillDownCategoryId == null) ...[
                  Text('支出分类',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 240,
                    child: PieChart(
                      PieChartData(
                        sections: pieSections,
                        centerSpaceRadius: 40,
                        sectionsSpace: 2,
                        pieTouchData: PieTouchData(
                          touchCallback: (event, response) {
                            if (event is FlTapUpEvent &&
                                response?.touchedSection != null) {
                              final idx = response!.touchedSection!.touchedSectionIndex;
                              if (idx < sortedCats.length) {
                                setState(() {
                                  _drillDownCategoryId = sortedCats[idx].key;
                                });
                              }
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Category list
                  ...sortedCats.map((entry) {
                    final cat = provider.getCategoryById(entry.key);
                    final percent = totalExpense > 0
                        ? entry.value / totalExpense * 100
                        : 0.0;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: cat != null
                            ? Color(int.parse(cat.color))
                            : Colors.grey,
                        radius: 14,
                        child: Text(cat?.name.substring(0, 1) ?? '?',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11)),
                      ),
                      title: Text(cat?.name ?? '未知',
                          style: const TextStyle(fontSize: 14)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(currencyFormat.format(entry.value / 100),
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          Text('${percent.toStringAsFixed(1)}%',
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      onTap: () {
                        setState(() => _drillDownCategoryId = entry.key);
                      },
                    );
                  }),
                ],

                // Drill-down: category detail
                if (_drillDownCategoryId != null) ...[
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => setState(() => _drillDownCategoryId = null),
                      ),
                      Text(
                        provider.getCategoryById(_drillDownCategoryId!)?.name ?? '分类明细',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...filteredTxs
                      .where((t) =>
                          t.type == 0 && t.categoryId == _drillDownCategoryId)
                      .map((tx) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 4),
                      child: ListTile(
                        title: Text(tx.note?.isNotEmpty == true
                            ? tx.note!
                            : '无备注'),
                        subtitle: Text(tx.date),
                        trailing: Text(
                          currencyFormat.format(tx.amount / 100),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.error,
                          ),
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
