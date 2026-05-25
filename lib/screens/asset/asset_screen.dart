import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/transaction_provider.dart';
import '../account/account_edit_screen.dart';
import '../account/account_transfer_screen.dart';
import '../credit/credit_card_screen.dart';
import '../debt/debt_list_screen.dart';
import '../saving/saving_list_screen.dart';
import '../investment/investment_list_screen.dart';

class AssetScreen extends StatelessWidget {
  const AssetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final currencyFormat =
        NumberFormat.currency(symbol: '¥', decimalDigits: 2);
    final netWorth = provider.netWorth;

    int totalAssets = 0;
    int totalLiabilities = 0;
    for (final a in provider.allAccounts) {
      if (a.type == 4) continue; // 投资账户不计入净资产
      if (a.type == 2) {
        totalLiabilities += a.balance < 0 ? -a.balance : 0;
      } else if (a.balance > 0) {
        totalAssets += a.balance;
      } else {
        totalLiabilities += -a.balance;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('资产'),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: '转账',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider.value(
                  value: provider,
                  child: const AccountTransferScreen(),
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
                  Text(currencyFormat.format(netWorth),
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatItem(
                          label: '总资产',
                          value: currencyFormat.format(totalAssets / 100),
                          color: Theme.of(context).colorScheme.tertiary),
                      _StatItem(
                          label: '总负债',
                          value: currencyFormat.format(totalLiabilities / 100),
                          color: Theme.of(context).colorScheme.error),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 快捷入口
          Row(children: [
            Expanded(child: _QuickEntry(
              icon: Icons.credit_card, label: '信用卡', color: Colors.orange,
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider.value(value: provider, child: const CreditCardScreen()),
              )),
            )),
            const SizedBox(width: 8),
            Expanded(child: _QuickEntry(
              icon: Icons.handshake, label: '债务', color: Colors.red,
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider.value(value: provider, child: const DebtListScreen()),
              )),
            )),
            const SizedBox(width: 8),
            Expanded(child: _QuickEntry(
              icon: Icons.savings, label: '存钱计划', color: Colors.green,
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider.value(value: provider, child: const SavingListScreen()),
              )),
            )),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _QuickEntry(
              icon: Icons.trending_up, label: '投资持仓', color: const Color(0xFF0097A7),
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider.value(value: provider, child: const InvestmentListScreen()),
              )),
            )),
            const SizedBox(width: 8),
            const Expanded(child: SizedBox()),
            const SizedBox(width: 8),
            const Expanded(child: SizedBox()),
          ]),
          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('账户列表',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),

          if (provider.allAccounts.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text('暂无账户',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.outline)),
              ),
            )
          else
            ...provider.allAccounts.map((account) {
              final typeNames = ['现金', '借记卡', '信用卡', '储值卡', '投资'];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _showAccountOptions(context, account),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Color(int.parse(account.color)),
                          radius: 18,
                          child: Text(account.name.substring(0, 1),
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 13)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(account.name,
                                  style: const TextStyle(fontSize: 15)),
                              Text(typeNames[account.type.clamp(0, 4)],
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outline,
                                      fontSize: 13)),
                              if (account.type == 2 &&
                                  account.creditLimit != null)
                                Text(
                                  '额度: ${currencyFormat.format(account.creditLimit! / 100)}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          currencyFormat.format(account.balance / 100),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: account.balance >= 0
                                ? Theme.of(context).colorScheme.tertiary
                                : Theme.of(context).colorScheme.error,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right,
                            color: Colors.grey, size: 20),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'asset_fab',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider.value(
              value: provider,
              child: const AccountEditScreen(),
            ),
          ),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAccountOptions(BuildContext context, dynamic account) {
    final provider = context.read<TransactionProvider>();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(account.name,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('编辑账户'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChangeNotifierProvider.value(
                        value: provider,
                        child: AccountEditScreen(account: account),
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: const Text('转账'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChangeNotifierProvider.value(
                        value: provider,
                        child: const AccountTransferScreen(),
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error),
                title: Text('删除账户',
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDelete(context, account);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, dynamic account) {
    final provider = context.read<TransactionProvider>();
    final hasRef =
        provider.transactions.any((t) => t.accountId == account.id);
    if (hasRef) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该账户下已有交易记录，无法删除')),
      );
      return;
    }
    if (provider.allAccounts.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('至少保留一个账户')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除账户'),
        content: Text('确定删除「${account.name}」吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              provider.deleteAccount(account.id);
              Navigator.pop(ctx);
            },
            child: Text('删除',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem(
      {required this.label, required this.value, required this.color});

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

class _QuickEntry extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickEntry({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w500)),
          ]),
        ),
      ),
    );
  }
}
