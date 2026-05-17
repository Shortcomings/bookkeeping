import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/transaction_provider.dart';

class AccountTransferScreen extends StatefulWidget {
  const AccountTransferScreen({super.key});

  @override
  State<AccountTransferScreen> createState() => _AccountTransferScreenState();
}

class _AccountTransferScreenState extends State<AccountTransferScreen> {
  String? _fromId;
  String? _toId;
  String _amount = '';
  String _note = '';
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final accounts = provider.allAccounts;
    final currencyFormat =
        NumberFormat.currency(symbol: '¥', decimalDigits: 2);

    final fromAccount =
        _fromId != null ? accounts.firstWhere((a) => a.id == _fromId) : null;
    final toAccount =
        _toId != null ? accounts.firstWhere((a) => a.id == _toId) : null;
    final validAccounts = _fromId != null
        ? accounts.where((a) => a.id != _fromId).toList()
        : accounts;

    return Scaffold(
      appBar: AppBar(title: const Text('转账')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 转出
          Text('转出账户', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          if (accounts.isEmpty)
            const Text('暂无账户')
          else
            ...accounts.map((a) => _AccountCard(
                  account: a,
                  selected: _fromId == a.id,
                  onTap: () => setState(() {
                    _fromId = a.id;
                    if (_toId == a.id) _toId = null;
                  }),
                )),
          const SizedBox(height: 20),

          // 转入
          Text('转入账户', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          if (_fromId == null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('请先选择转出账户',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.outline)),
            )
          else if (validAccounts.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('没有可用账户',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.outline)),
            )
          else
            ...validAccounts.map((a) => _AccountCard(
                  account: a,
                  selected: _toId == a.id,
                  onTap: () => setState(() => _toId = a.id),
                )),
          const SizedBox(height: 20),

          // 金额
          TextField(
            decoration: const InputDecoration(
              labelText: '转账金额',
              prefixText: '¥ ',
              border: OutlineInputBorder(),
            ),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            style: Theme.of(context).textTheme.headlineSmall,
            onChanged: (v) => _amount = v,
          ),
          const SizedBox(height: 16),

          // 备注
          TextField(
            decoration: const InputDecoration(
              labelText: '备注（可选）',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => _note = v,
          ),
          const SizedBox(height: 8),

          // 预览
          if (fromAccount != null && toAccount != null && _amount.isNotEmpty)
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Text('${fromAccount.name} → ${toAccount.name}',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text('¥ $_amount',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                            '${fromAccount.name} 余额: ${currencyFormat.format(fromAccount.balance / 100)}'),
                        Text(
                            '→ ${currencyFormat.format(fromAccount.balance / 100 - (double.tryParse(_amount) ?? 0))}',
                            style: TextStyle(
                                color:
                                    Theme.of(context).colorScheme.outline)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                            '${toAccount.name} 余额: ${currencyFormat.format(toAccount.balance / 100)}'),
                        Text(
                            '→ ${currencyFormat.format(toAccount.balance / 100 + (double.tryParse(_amount) ?? 0))}',
                            style: TextStyle(
                                color:
                                    Theme.of(context).colorScheme.tertiary)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),

          FilledButton(
            onPressed: _fromId != null &&
                    _toId != null &&
                    _amount.isNotEmpty &&
                    !_saving
                ? _transfer
                : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('确认转账'),
          ),
        ],
      ),
    );
  }

  Future<void> _transfer() async {
    final amount = double.tryParse(_amount);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效金额')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await context.read<TransactionProvider>().transferBetweenAccounts(
            fromAccountId: _fromId!,
            toAccountId: _toId!,
            amount: (amount * 100).round(),
          );
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('转账失败: $e')),
        );
      }
    }
  }
}

class _AccountCard extends StatelessWidget {
  final dynamic account;
  final bool selected;
  final VoidCallback onTap;

  const _AccountCard({
    required this.account,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: selected
          ? Theme.of(context).colorScheme.primaryContainer
          : null,
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Color(int.parse(account.color)),
          radius: 16,
          child: Text(account.name.substring(0, 1),
              style: const TextStyle(color: Colors.white, fontSize: 12)),
        ),
        title: Text(account.name),
        trailing: Text(
          NumberFormat.currency(symbol: '¥', decimalDigits: 2)
              .format(account.balance / 100),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: account.balance >= 0
                ? Theme.of(context).colorScheme.tertiary
                : Theme.of(context).colorScheme.error,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
