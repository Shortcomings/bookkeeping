import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/auto_bookkeeping_service.dart';
import '../../services/nlp_parser.dart';
import '../../providers/transaction_provider.dart';
import '../transaction/add_transaction_sheet.dart';

class AutoBookkeepingReviewSheet extends StatefulWidget {
  final List<PendingAutoTransaction> pendingTransactions;
  const AutoBookkeepingReviewSheet(
      {super.key, required this.pendingTransactions});

  @override
  State<AutoBookkeepingReviewSheet> createState() =>
      _AutoBookkeepingReviewSheetState();
}

class _AutoBookkeepingReviewSheetState
    extends State<AutoBookkeepingReviewSheet> {
  late List<_ReviewItem> _items;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _items = widget.pendingTransactions.map((tx) {
      final match = NlpParser.matchCategoryFromText(tx.merchantName);
      return _ReviewItem(
        pending: tx,
        matchedCategory: match.categoryName,
        matchedType: match.type,
        status: _ReviewStatus.pending,
      );
    }).toList();
  }

  Future<void> _confirmAll() async {
    setState(() => _importing = true);
    final provider = context.read<TransactionProvider>();
    final service = AutoBookkeepingService();
    int imported = 0;

    for (final item
        in _items.where((i) => i.status != _ReviewStatus.dismissed)) {
      final success = await provider.importAutoTransaction(
        merchantName: item.pending.merchantName,
        amountCents: item.pending.amountCents,
        type: item.matchedType,
        date: item.pending.date,
        sourceApp: item.pending.sourceApp,
      );
      if (success) {
        item.status = _ReviewStatus.confirmed;
        imported++;
      }
    }

    await service.clearPendingTransactions();
    if (!mounted) return;
    setState(() => _importing = false);
    Navigator.of(context).pop(imported);
  }

  Future<void> _editItem(int index) async {
    final item = _items[index];
    // Show edit sheet on top of review sheet (don't pop first — would invalidate context)
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<TransactionProvider>(),
        child: AddTransactionSheet(
          prefillData: {
            'amount': (item.pending.amountCents / 100).toStringAsFixed(2),
            'type': item.matchedType,
            'note': item.pending.merchantName,
            'date': item.pending.date,
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat =
        NumberFormat.currency(symbol: '¥', decimalDigits: 2);
    final activeItems =
        _items.where((i) => i.status != _ReviewStatus.dismissed).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .outline
                    .withAlpha(80),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.notifications_active_outlined,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text('自动记账审核',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${activeItems.length} 条待导入',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 12),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                final tx = item.pending;
                final isExpense = item.matchedType == 0;
                final dismissed =
                    item.status == _ReviewStatus.dismissed;
                final confirmed =
                    item.status == _ReviewStatus.confirmed;

                return Opacity(
                  opacity: dismissed ? 0.35 : 1.0,
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2),
                                decoration: BoxDecoration(
                                  color: tx.sourceApp == '微信'
                                      ? Colors.green.withAlpha(30)
                                      : Colors.blue.withAlpha(30),
                                  borderRadius:
                                      BorderRadius.circular(4),
                                ),
                                child: Text(
                                  tx.sourceApp,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: tx.sourceApp == '微信'
                                        ? Colors.green.shade700
                                        : Colors.blue.shade700,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${isExpense ? "-" : "+"}${currencyFormat.format(tx.amountCents / 100)}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: isExpense
                                      ? Theme.of(context)
                                          .colorScheme
                                          .error
                                      : Theme.of(context)
                                          .colorScheme
                                          .tertiary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(tx.merchantName,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(tx.date,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall),
                              const SizedBox(width: 8),
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 1),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer,
                                  borderRadius:
                                      BorderRadius.circular(3),
                                ),
                                child: Text(
                                  '匹配: ${item.matchedCategory}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (!confirmed && !dismissed) ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () =>
                                      setState(() => item.status =
                                          _ReviewStatus
                                              .dismissed),
                                  child: const Text('忽略',
                                      style:
                                          TextStyle(fontSize: 12)),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: () {
                                    _editItem(index);
                                  },
                                  style: OutlinedButton.styleFrom(
                                    padding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 12),
                                    minimumSize:
                                        const Size(0, 32),
                                  ),
                                  child: const Text('编辑',
                                      style:
                                          TextStyle(fontSize: 12)),
                                ),
                                const SizedBox(width: 8),
                                FilledButton(
                                  onPressed: () => setState(() =>
                                      item.status = _ReviewStatus
                                          .confirmed),
                                  style: FilledButton.styleFrom(
                                    padding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 12),
                                    minimumSize:
                                        const Size(0, 32),
                                  ),
                                  child: const Text('确认',
                                      style:
                                          TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                          ],
                          if (confirmed)
                            Padding(
                              padding:
                                  const EdgeInsets.only(top: 4),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.end,
                                children: [
                                  Icon(Icons.check_circle,
                                      size: 14,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary),
                                  const SizedBox(width: 4),
                                  Text('已确认',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      )),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed:
                _importing || activeItems.isEmpty ? null : _confirmAll,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
            child: _importing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text('确认导入 (${activeItems.length})'),
          ),
        ],
      ),
    );
  }
}

enum _ReviewStatus { pending, confirmed, dismissed }

class _ReviewItem {
  final PendingAutoTransaction pending;
  final String matchedCategory;
  final int matchedType;
  _ReviewStatus status;
  _ReviewItem({
    required this.pending,
    required this.matchedCategory,
    required this.matchedType,
    this.status = _ReviewStatus.pending,
  });
}
