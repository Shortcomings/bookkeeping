import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/transaction_provider.dart';

class AssetScreen extends StatelessWidget {
  const AssetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final currencyFormat = NumberFormat.currency(symbol: '¥', decimalDigits: 2);

    final totalAsset = provider.accounts
        .fold<int>(0, (sum, a) => sum + (a.balance > 0 ? a.balance : 0));
    final totalLiability = provider.accounts
        .fold<int>(0, (sum, a) => sum + (a.balance < 0 ? -a.balance : 0));
    final netWorth = totalAsset - totalLiability;

    return Scaffold(
      appBar: AppBar(title: const Text('资产')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 净资产卡片
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text('净资产',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer
                              .withAlpha(179))),
                  const SizedBox(height: 4),
                  Text(currencyFormat.format(netWorth / 100),
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _AssetStat(label: '总资产',
                          value: currencyFormat.format(totalAsset / 100),
                          color: Theme.of(context).colorScheme.tertiary),
                      _AssetStat(label: '总负债',
                          value: currencyFormat.format(totalLiability / 100),
                          color: Theme.of(context).colorScheme.error),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text('账户列表',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),

          if (provider.accounts.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text('暂无账户',
                    style: TextStyle(color: Theme.of(context).colorScheme.outline)),
              ),
            )
          else
            ...provider.accounts.map((account) {
              final typeNames = ['现金', '借记卡', '信用卡', '储值卡', '投资'];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Color(int.parse(account.color)),
                    radius: 18,
                    child: Text(account.name.substring(0, 1),
                        style: const TextStyle(color: Colors.white, fontSize: 13)),
                  ),
                  title: Text(account.name, style: const TextStyle(fontSize: 15)),
                  subtitle: Text(typeNames[account.type.clamp(0, 4)]),
                  trailing: Text(
                    currencyFormat.format(account.balance / 100),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: account.balance >= 0
                          ? Theme.of(context).colorScheme.tertiary
                          : Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _AssetStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _AssetStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onPrimaryContainer.withAlpha(179))),
        const SizedBox(height: 4),
        Text(value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}
