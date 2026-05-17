import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/transaction_provider.dart';

class BudgetEditScreen extends StatefulWidget {
  final String month;
  const BudgetEditScreen({super.key, required this.month});

  @override
  State<BudgetEditScreen> createState() => _BudgetEditScreenState();
}

class _BudgetEditScreenState extends State<BudgetEditScreen> {
  String _totalAmount = '';
  final Map<String, String> _categoryAmounts = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<TransactionProvider>();
    final total = provider.getTotalBudget(widget.month);
    if (total != null) {
      _totalAmount = (total.totalAmount / 100).toStringAsFixed(0);
    }
    for (final b in provider.getCategoryBudgets(widget.month)) {
      _categoryAmounts[b.categoryId!] =
          (b.totalAmount / 100).toStringAsFixed(0);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final provider = context.read<TransactionProvider>();

    final total = double.tryParse(_totalAmount) ?? 0;
    await provider.setTotalBudget(widget.month, (total * 100).round());

    for (final entry in _categoryAmounts.entries) {
      final amount = double.tryParse(entry.value) ?? 0;
      await provider.setCategoryBudget(
          widget.month, entry.key, (amount * 100).round());
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final expenseCats = provider.allCategories
        .where((c) => c.type == 0 && c.isEnabled)
        .toList();
    final currencyFormat =
        NumberFormat.currency(symbol: '¥', decimalDigits: 2);

    return Scaffold(
      appBar: AppBar(
        title: Text(
            '设置 ${widget.month.substring(0, 4)}年${widget.month.substring(5)}月预算'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 总预算
          Text('总预算', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            decoration: const InputDecoration(
              prefixText: '¥ ',
              border: OutlineInputBorder(),
              hintText: '0',
            ),
            keyboardType: TextInputType.number,
            controller: TextEditingController(text: _totalAmount),
            onChanged: (v) => _totalAmount = v,
          ),
          const SizedBox(height: 24),

          // 分类预算
          Text('分类预算（选填）',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...expenseCats.map((cat) {
            final monthTxs = provider
                .getTransactionsByMonthString(widget.month)
                .where((t) => t.type == 0 && t.categoryId == cat.id)
                .toList();
            final spent = monthTxs
                .fold<int>(0, (s, t) => s + t.amount);
            return Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor:
                          Color(int.parse(cat.color)),
                      radius: 14,
                      child: Text(cat.name.substring(0, 1),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(cat.name,
                              style: const TextStyle(
                                  fontSize: 14)),
                          Text(
                            '本月已花 ${currencyFormat.format(spent / 100)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: TextField(
                        decoration: const InputDecoration(
                          prefixText: '¥',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding:
                              EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8),
                        ),
                        keyboardType: TextInputType.number,
                        controller: TextEditingController(
                            text: _categoryAmounts[
                                cat.id]),
                        onChanged: (v) =>
                            _categoryAmounts[cat.id] = v,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 24),

          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              minimumSize:
                  const Size(double.infinity, 48),
            ),
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white),
                  )
                : const Text('保存预算'),
          ),
        ],
      ),
    );
  }
}
