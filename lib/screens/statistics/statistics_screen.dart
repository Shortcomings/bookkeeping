import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/transaction_provider.dart';
import '../../services/export_service.dart';
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
    _tabController = TabController(length: 5, vsync: this);
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

    final tabLabels = ['本周', '本月', '本年', '对比', '高级'];

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
          : _selectedTab == 4
          ? _buildAdvancedReport(context)
          : filteredTxs.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.pie_chart_outline,
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

  Widget _buildAdvancedReport(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final currencyFormat = NumberFormat.currency(symbol: '¥', decimalDigits: 2);

    // Balance sheet
    final accounts = provider.allAccounts.where((a) => a.type != 4).toList();
    int totalAssets = 0;
    int totalLiabilities = 0;
    for (final a in accounts) {
      if (a.type == 2) {
        totalLiabilities += a.balance < 0 ? -a.balance : 0;
      } else if (a.balance > 0) {
        totalAssets += a.balance;
      } else {
        totalLiabilities += -a.balance;
      }
    }
    totalAssets += provider.totalInvestmentValue;
    final netWorth = totalAssets - totalLiabilities;

    // Cash flow
    final cashFlow = provider.getMonthlyCashFlow();

    // Net worth trend data
    int runningNetWorth = netWorth;
    final netWorthPoints = <FlSpot>[];
    for (int i = cashFlow.length - 1; i >= 0; i--) {
      runningNetWorth -= cashFlow[i].net;
      netWorthPoints.insert(0, FlSpot((cashFlow.length - 1 - i).toDouble(), (runningNetWorth / 100).toDouble()));
    }
    netWorthPoints.add(FlSpot((cashFlow.length).toDouble(), (netWorth / 100).toDouble()));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 资产负债表
        Text('资产负债表', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _StatItem(label: '总资产', value: currencyFormat.format(totalAssets / 100), color: Theme.of(context).colorScheme.tertiary),
                _StatItem(label: '总负债', value: currencyFormat.format(totalLiabilities / 100), color: Theme.of(context).colorScheme.error),
                _StatItem(label: '净资产', value: currencyFormat.format(netWorth / 100), color: netWorth >= 0 ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.error),
              ]),
              const SizedBox(height: 16),
              ...accounts.map((a) {
                final names = ['现金', '借记卡', '信用卡', '储值卡', '投资'];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(names[a.type.clamp(0, 4)], style: Theme.of(context).textTheme.bodySmall),
                    Text(currencyFormat.format(a.balance / 100), style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500)),
                  ]),
                );
              }),
              if (provider.totalInvestmentValue > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('投资持仓', style: TextStyle(fontSize: 12)),
                    Text(currencyFormat.format(provider.totalInvestmentValue / 100), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  ]),
                ),
            ]),
          ),
        ),

        const SizedBox(height: 24),

        // 现金流表
        Text('现金流表', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 16,
                columns: const [
                  DataColumn(label: Text('月份', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                  DataColumn(label: Text('收入', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                  DataColumn(label: Text('支出', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                  DataColumn(label: Text('净现金流', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                ],
                rows: cashFlow.map((cf) => DataRow(cells: [
                  DataCell(Text(cf.month.substring(5).replaceFirst('-', '/'), style: const TextStyle(fontSize: 11))),
                  DataCell(Text(currencyFormat.format(cf.income / 100), style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.tertiary))),
                  DataCell(Text(currencyFormat.format(cf.expense / 100), style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.error))),
                  DataCell(Text(currencyFormat.format(cf.net / 100), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: cf.net >= 0 ? Theme.of(context).colorScheme.tertiary : Theme.of(context).colorScheme.error))),
                ])).toList(),
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // 净资产趋势图
        Text('净资产趋势', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 240,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: netWorth > 0 ? (netWorth / 500).round().clamp(1, 99999) * 100.0 : 100),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 60, getTitlesWidget: (value, meta) => Text(currencyFormat.format(value), style: const TextStyle(fontSize: 10)))),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx >= 0 && idx < cashFlow.length) {
                        return Text(cashFlow[idx].month.substring(5, 7), style: const TextStyle(fontSize: 9));
                      }
                      return const Text('');
                    })),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: netWorthPoints,
                      isCurved: true,
                      color: Theme.of(context).colorScheme.primary,
                      barWidth: 2,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(show: true, color: Theme.of(context).colorScheme.primary.withAlpha(30)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // 导出按钮
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                try {
                  await ExportService.exportAdvancedReport(provider);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导出失败: $e')));
                  }
                }
              },
              icon: const Icon(Icons.file_download, size: 18),
              label: const Text('导出报表 CSV'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                try {
                  await ExportService.exportToCsv(provider);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导出失败: $e')));
                  }
                }
              },
              icon: const Icon(Icons.table_chart, size: 18),
              label: const Text('导出账单 CSV'),
            ),
          ),
        ]),
        const SizedBox(height: 40),
      ],
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
