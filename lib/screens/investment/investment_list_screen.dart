import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/transaction_provider.dart';
import '../../models/investment.dart';
import 'investment_edit_screen.dart';
import 'investment_detail_screen.dart';

class InvestmentListScreen extends StatelessWidget {
  const InvestmentListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final investments = provider.investments;
    final currencyFormat = NumberFormat.currency(symbol: '¥', decimalDigits: 2);
    final totalValue = provider.totalInvestmentValue;
    final totalCost = provider.totalInvestmentCost;
    final totalPL = provider.totalInvestmentProfitLoss;
    final plPercent = totalCost > 0 ? (totalPL / totalCost * 100) : 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text('投资持仓')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                Text('持仓市值', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onPrimaryContainer.withAlpha(179))),
                const SizedBox(height: 4),
                Text(currencyFormat.format(totalValue / 100), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onPrimaryContainer)),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  _SummaryItem(label: '成本', value: currencyFormat.format(totalCost / 100), context: context),
                  _SummaryItem(label: '盈亏', value: '${totalPL >= 0 ? "+" : ""}${currencyFormat.format(totalPL / 100)}', color: totalPL >= 0 ? Theme.of(context).colorScheme.tertiary : Theme.of(context).colorScheme.error, context: context),
                  _SummaryItem(label: '收益率', value: '${plPercent.toStringAsFixed(2)}%', color: plPercent >= 0 ? Theme.of(context).colorScheme.tertiary : Theme.of(context).colorScheme.error, context: context),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          if (investments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 80),
              child: Center(
                child: Column(children: [
                  Icon(Icons.trending_up, size: 64, color: Theme.of(context).colorScheme.outline.withAlpha(100)),
                  const SizedBox(height: 16),
                  Text('暂无持仓', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.outline)),
                  const SizedBox(height: 8),
                  Text('点击右下角按钮添加第一笔投资', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline)),
                ]),
              ),
            )
          else
            ...investments.map((inv) => _HoldingCard(
                  investment: inv,
                  currencyFormat: currencyFormat,
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ChangeNotifierProvider.value(value: provider, child: InvestmentDetailScreen(investment: inv)),
                  )),
                )),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'investment_fab',
        onPressed: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(value: provider, child: const InvestmentEditScreen()),
        )).then((_) => provider.loadInvestments()),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final BuildContext context;

  const _SummaryItem({required this.label, required this.value, this.color, required this.context});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onPrimaryContainer.withAlpha(179))),
      const SizedBox(height: 4),
      Text(value, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600,
          color: color ?? Theme.of(context).colorScheme.onPrimaryContainer)),
    ]);
  }
}

class _HoldingCard extends StatelessWidget {
  final Investment investment;
  final NumberFormat currencyFormat;
  final VoidCallback onTap;

  const _HoldingCard({required this.investment, required this.currencyFormat, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final inv = investment;
    final types = ['股票', '基金', '数字货币', '定期'];
    final typeName = inv.type >= 0 && inv.type < types.length ? types[inv.type] : '其他';
    final pl = inv.profitLoss;
    final plPct = inv.profitLossPercent;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            CircleAvatar(
              backgroundColor: Color(int.parse('0xFF5C6BC0')),
              radius: 22,
              child: Text(inv.name.substring(0, 1), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(inv.name, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  if (inv.code != null) ...[
                    const SizedBox(width: 6),
                    Text(inv.code!, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.outline)),
                  ],
                ]),
                const SizedBox(height: 2),
                Text('${(inv.shares / 1000).toStringAsFixed(3)} 股 · $typeName',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(currencyFormat.format(inv.currentValue / 100),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              Text('${pl >= 0 ? "+" : ""}${(plPct * 100).toStringAsFixed(2)}%',
                  style: TextStyle(fontSize: 12, color: pl >= 0 ? Theme.of(context).colorScheme.tertiary : Theme.of(context).colorScheme.error)),
            ]),
          ]),
        ),
      ),
    );
  }
}
