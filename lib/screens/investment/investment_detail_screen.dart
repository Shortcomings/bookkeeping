import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/transaction_provider.dart';
import '../../models/investment.dart';
import 'investment_edit_screen.dart';

class InvestmentDetailScreen extends StatefulWidget {
  final Investment investment;
  const InvestmentDetailScreen({super.key, required this.investment});

  @override
  State<InvestmentDetailScreen> createState() => _InvestmentDetailScreenState();
}

class _InvestmentDetailScreenState extends State<InvestmentDetailScreen> {
  int _tradeType = 0; // 0=buy, 1=sell, 2=dividend, 3=interest
  String _tradeShares = '';
  String _tradePrice = '';
  String _tradeAmount = '';
  String _tradeDate = '';
  String _tradeNote = '';
  bool _saving = false;
  final _tradeTypes = ['买入', '卖出', '分红', '利息'];
  final _currencyFormat = NumberFormat.currency(symbol: '¥', decimalDigits: 2);

  late Investment _inv;

  @override
  void initState() {
    super.initState();
    _inv = widget.investment;
    _tradeDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  @override
  void didUpdateWidget(covariant InvestmentDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _inv = widget.investment;
  }

  Future<void> _addTrade() async {
    final shares = ((double.tryParse(_tradeShares) ?? 0) * 1000).round();
    final price = ((double.tryParse(_tradePrice) ?? 0) * 100).round();
    int amount;

    if (_tradeType == 0 || _tradeType == 1) {
      amount = ((double.tryParse(_tradeAmount) ?? 0) * 100).round();
      if (shares <= 0 || amount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入数量和金额')));
        return;
      }
      if (_tradeType == 1) {
        // Sell: check enough shares
        if (shares > _inv.shares) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('卖出数量不能超过持仓')));
          return;
        }
      }
    } else {
      // Dividend/interest: use amount field only
      amount = ((double.tryParse(_tradeAmount) ?? 0) * 100).round();
      if (amount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入金额')));
        return;
      }
    }

    setState(() => _saving = true);
    final provider = context.read<TransactionProvider>();

    try {
      await provider.addTrade(
        investmentId: _inv.id,
        type: _tradeType,
        shares: shares,
        price: price,
        amount: amount,
        date: _tradeDate,
        note: _tradeNote.isNotEmpty ? _tradeNote : null,
      );
      // Refresh local state
      setState(() {
        _tradeShares = '';
        _tradePrice = '';
        _tradeAmount = '';
        _tradeNote = '';
        _saving = false;
        final idx = provider.investments.indexWhere((i) => i.id == _inv.id);
        if (idx != -1) _inv = provider.investments[idx];
      });
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败: $e')));
    }
  }

  Future<void> _deleteTrade(String tradeId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('删除此交易将回退持仓变动，确定继续？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (confirm != true) return;

    final provider = context.read<TransactionProvider>();
    await provider.deleteTrade(tradeId);
    setState(() {
      final idx = provider.investments.indexWhere((i) => i.id == _inv.id);
      if (idx != -1) _inv = provider.investments[idx];
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<TransactionProvider>();
    final trades = provider.getTrades(_inv.id);
    final pl = _inv.profitLoss;
    final plPct = _inv.profitLossPercent;
    final types = ['股票', '基金', '数字货币', '定期'];

    return Scaffold(
      appBar: AppBar(
        title: Text(_inv.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => ChangeNotifierProvider.value(
                value: provider,
                child: InvestmentEditScreen(investment: _inv),
              ),
            )).then((_) {
              final idx = provider.investments.indexWhere((i) => i.id == _inv.id);
              if (idx != -1) setState(() => _inv = provider.investments[idx]);
            }),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 持仓概览
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(_inv.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onPrimaryContainer)),
                  if (_inv.code != null) ...[
                    const SizedBox(width: 8),
                    Text(_inv.code!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onPrimaryContainer.withAlpha(179))),
                  ],
                ]),
                const SizedBox(height: 4),
                Text(types[_inv.type.clamp(0, 3)], style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onPrimaryContainer.withAlpha(150))),
                const SizedBox(height: 16),
                Text(_currencyFormat.format(_inv.currentValue / 100),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onPrimaryContainer)),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  _buildInfoColumn('股数', '${(_inv.shares / 1000).toStringAsFixed(3)}', context),
                  _buildInfoColumn('成本', _currencyFormat.format(_inv.costBasis / 100), context),
                  _buildInfoColumn('盈亏', '${pl >= 0 ? "+" : ""}${_currencyFormat.format(pl / 100)}', context,
                      color: pl >= 0 ? Colors.green : Theme.of(context).colorScheme.error),
                  _buildInfoColumn('收益率', '${(plPct * 100).toStringAsFixed(2)}%', context,
                      color: plPct >= 0 ? Colors.green : Theme.of(context).colorScheme.error),
                ]),
              ]),
            ),
          ),

          const SizedBox(height: 24),
          Text('交易记录', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),

          if (trades.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text('暂无交易记录', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.outline))),
            )
          else
            ...trades.map((trade) => Card(
                  margin: const EdgeInsets.only(bottom: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: _tradeTypeColor(trade.type, context),
                      child: Text(_tradeTypes[trade.type.clamp(0, 3)].substring(0, 1),
                          style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                    title: Text(_tradeTypes[trade.type.clamp(0, 3)],
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    subtitle: Text(trade.date,
                        style: Theme.of(context).textTheme.labelSmall),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(_currencyFormat.format(trade.amount / 100),
                            style: TextStyle(fontWeight: FontWeight.w600, color: trade.type == 0 ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.tertiary)),
                        if (trade.shares > 0) Text('${(trade.shares / 1000).toStringAsFixed(1)}股', style: Theme.of(context).textTheme.labelSmall),
                      ]),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        onPressed: () => _deleteTrade(trade.id),
                      ),
                    ]),
                  ),
                )),

          const SizedBox(height: 24),
          Text('添加交易', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),

          // 交易类型
          Wrap(spacing: 8, children: List.generate(_tradeTypes.length, (i) => ChoiceChip(
            label: Text(_tradeTypes[i], style: const TextStyle(fontSize: 13)),
            selected: _tradeType == i,
            onSelected: (_) => setState(() => _tradeType = i),
          ))),
          const SizedBox(height: 8),

          // 交易表单
          if (_tradeType == 0 || _tradeType == 1) ...[
            TextFormField(
              decoration: InputDecoration(
                labelText: '数量（股/份）',
                hintText: '如：100',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType: TextInputType.number,
              onChanged: (v) => _tradeShares = v,
            ),
            const SizedBox(height: 8),
            TextFormField(
              decoration: InputDecoration(
                labelText: '单价',
                prefixText: '¥ ',
                hintText: '0.00',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) => _tradePrice = v,
            ),
            const SizedBox(height: 8),
          ],
          if (_tradeType == 0 || _tradeType == 1) ...[
            TextFormField(
              decoration: InputDecoration(
                labelText: '总金额',
                prefixText: '¥ ',
                hintText: '0.00',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) => _tradeAmount = v,
            ),
          ] else ...[
            TextFormField(
              decoration: InputDecoration(
                labelText: _tradeType == 2 ? '分红金额' : '利息金额',
                prefixText: '¥ ',
                hintText: '0.00',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) => _tradeAmount = v,
            ),
          ],
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime.tryParse(_tradeDate) ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (date != null) setState(() => _tradeDate = DateFormat('yyyy-MM-dd').format(date));
            },
            child: InputDecorator(
              decoration: const InputDecoration(labelText: '日期', border: OutlineInputBorder(), isDense: true, suffixIcon: Icon(Icons.calendar_today, size: 18)),
              child: Text(_tradeDate),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            decoration: const InputDecoration(labelText: '备注', border: OutlineInputBorder(), isDense: true),
            onChanged: (v) => _tradeNote = v,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving ? null : _addTrade,
            style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 44)),
            child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('添加交易'),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value, BuildContext context, {Color? color}) {
    return Column(children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onPrimaryContainer.withAlpha(179))),
      const SizedBox(height: 2),
      Text(value, style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600, color: color ?? Theme.of(context).colorScheme.onPrimaryContainer)),
    ]);
  }

  Color _tradeTypeColor(int type, BuildContext context) {
    switch (type) {
      case 0: return Theme.of(context).colorScheme.error;
      case 1: return Colors.orange;
      case 2:
      case 3: return Theme.of(context).colorScheme.tertiary;
      default: return Colors.grey;
    }
  }
}
