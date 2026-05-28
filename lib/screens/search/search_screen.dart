import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/transaction_provider.dart';
import '../../models/transaction.dart';
import '../transaction/add_transaction_sheet.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _keywordCtrl = TextEditingController();
  String _keyword = '';
  int? _typeFilter;
  String? _startDate;
  String? _endDate;
  String? _accountId;
  String? _categoryId;
  String _minAmount = '';
  String _maxAmount = '';
  bool _showFilters = false;

  @override
  void dispose() {
    _keywordCtrl.dispose();
    super.dispose();
  }

  List<Transaction> _search(TransactionProvider provider) {
    return provider.searchTransactions(
      keyword: _keyword,
      startDate: _startDate,
      endDate: _endDate,
      typeFilter: _typeFilter,
      minAmount: _minAmount.isNotEmpty
          ? ((double.tryParse(_minAmount) ?? 0) * 100).round()
          : null,
      maxAmount: _maxAmount.isNotEmpty
          ? ((double.tryParse(_maxAmount) ?? 0) * 100).round()
          : null,
      accountId: _accountId,
      categoryId: _categoryId,
    );
  }

  void _clearFilters() {
    setState(() {
      _keyword = '';
      _keywordCtrl.clear();
      _typeFilter = null;
      _startDate = null;
      _endDate = null;
      _accountId = null;
      _categoryId = null;
      _minAmount = '';
      _maxAmount = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final results = _search(provider);
    final hasFilters = _keyword.isNotEmpty ||
        _typeFilter != null ||
        _startDate != null ||
        _endDate != null ||
        _accountId != null ||
        _categoryId != null ||
        _minAmount.isNotEmpty ||
        _maxAmount.isNotEmpty;
    final currencyFormat =
        NumberFormat.currency(symbol: '¥', decimalDigits: 2);

    return Scaffold(
      appBar: AppBar(
        title: const Text('搜索'),
        actions: [
          if (hasFilters)
            TextButton(
              onPressed: _clearFilters,
              child: const Text('清除'),
            ),
        ],
      ),
      body: Column(
        children: [
          // 搜索栏
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _keywordCtrl,
                    decoration: InputDecoration(
                      hintText: '搜索金额、备注、分类...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                      suffixIcon: _keyword.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _keywordCtrl.clear();
                                setState(() => _keyword = '');
                              },
                            )
                          : null,
                    ),
                    onChanged: (v) => setState(() => _keyword = v),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    Icons.filter_list,
                    color: _showFilters
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  onPressed: () =>
                      setState(() => _showFilters = !_showFilters),
                ),
              ],
            ),
          ),

          // 筛选面板
          if (_showFilters)
            _FilterPanel(
              typeFilter: _typeFilter,
              onTypeChanged: (v) => setState(() => _typeFilter = v),
              startDate: _startDate,
              endDate: _endDate,
              onDateRangeChanged: (s, e) =>
                  setState(() { _startDate = s; _endDate = e; }),
              minAmount: _minAmount,
              maxAmount: _maxAmount,
              onMinAmountChanged: (v) =>
                  setState(() => _minAmount = v),
              onMaxAmountChanged: (v) =>
                  setState(() => _maxAmount = v),
              accountId: _accountId,
              onAccountChanged: (v) =>
                  setState(() => _accountId = v),
              categoryId: _categoryId,
              onCategoryChanged: (v) =>
                  setState(() => _categoryId = v),
            ),

          // 结果
          if (_keyword.isNotEmpty || hasFilters)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text('${results.length} 条结果',
                      style: Theme.of(context).textTheme.labelMedium),
                ],
              ),
            ),

          Expanded(
            child: results.isEmpty && hasFilters
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off,
                            size: 48,
                            color: Theme.of(context)
                                .colorScheme
                                .outline),
                        const SizedBox(height: 8),
                        Text('没有找到匹配的记录',
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outline)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final tx = results[index];
                      final cat =
                          provider.getCategoryById(tx.categoryId);
                      final isExpense = tx.type == 0;
                      final amount =
                          currencyFormat.format(tx.amount / 100);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 4),
                        child: InkWell(
                          borderRadius:
                              BorderRadius.circular(12),
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              useSafeArea: true,
                              shape: const RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.vertical(
                                        top: Radius.circular(16)),
                              ),
                              builder: (_) =>
                                  ChangeNotifierProvider.value(
                                value: provider,
                                child: AddTransactionSheet(
                                    editTransactionId: tx.id),
                              ),
                            );
                          },
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: cat != null
                                      ? Color(int.parse(
                                          cat.color))
                                      : Colors.grey,
                                  radius: 16,
                                  child: Text(
                                      cat?.name
                                              .substring(0, 1) ??
                                          '?',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11)),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment
                                            .start,
                                    children: [
                                      _HighlightedText(
                                        text: cat?.name ?? '未知',
                                        keyword: _keyword,
                                        style:
                                            const TextStyle(
                                                fontSize: 14),
                                      ),
                                      if (tx.note != null &&
                                          tx.note!
                                              .isNotEmpty)
                                        _HighlightedText(
                                          text: tx.note!,
                                          keyword: _keyword,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color:
                                                Theme.of(context)
                                                    .colorScheme
                                                    .outline,
                                          ),
                                        ),
                                      Text(
                                        tx.date,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color:
                                              Theme.of(context)
                                                  .colorScheme
                                                  .outline,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${isExpense ? '-' : '+'}$amount',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight:
                                        FontWeight.w600,
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
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _HighlightedText extends StatelessWidget {
  final String text;
  final String keyword;
  final TextStyle style;

  const _HighlightedText({
    required this.text,
    required this.keyword,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    if (keyword.isEmpty) return Text(text, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);

    final lower = text.toLowerCase();
    final kw = keyword.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;
    while (true) {
      final idx = lower.indexOf(kw, start);
      if (idx == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (idx > start) {
        spans.add(TextSpan(text: text.substring(start, idx)));
      }
      spans.add(TextSpan(
        text: text.substring(idx, idx + kw.length),
        style: TextStyle(
          backgroundColor: Colors.yellow.withAlpha(100),
          fontWeight: FontWeight.bold,
          color: style.color,
        ),
      ));
      start = idx + kw.length;
    }
    return RichText(
      text: TextSpan(style: style, children: spans),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _FilterPanel extends StatelessWidget {
  final int? typeFilter;
  final ValueChanged<int?> onTypeChanged;
  final String? startDate;
  final String? endDate;
  final void Function(String?, String?) onDateRangeChanged;
  final String minAmount;
  final String maxAmount;
  final ValueChanged<String> onMinAmountChanged;
  final ValueChanged<String> onMaxAmountChanged;
  final String? accountId;
  final ValueChanged<String?> onAccountChanged;
  final String? categoryId;
  final ValueChanged<String?> onCategoryChanged;

  const _FilterPanel({
    required this.typeFilter,
    required this.onTypeChanged,
    required this.startDate,
    required this.endDate,
    required this.onDateRangeChanged,
    required this.minAmount,
    required this.maxAmount,
    required this.onMinAmountChanged,
    required this.onMaxAmountChanged,
    required this.accountId,
    required this.onAccountChanged,
    required this.categoryId,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<TransactionProvider>();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 类型
          Wrap(
            spacing: 6,
            children: [
              FilterChip(
                label: const Text('全部'),
                selected: typeFilter == null,
                onSelected: (_) => onTypeChanged(null),
              ),
              FilterChip(
                label: const Text('支出'),
                selected: typeFilter == 0,
                onSelected: (_) => onTypeChanged(0),
                selectedColor: Theme.of(context)
                    .colorScheme
                    .error
                    .withAlpha(30),
              ),
              FilterChip(
                label: const Text('收入'),
                selected: typeFilter == 1,
                onSelected: (_) => onTypeChanged(1),
                selectedColor: Theme.of(context)
                    .colorScheme
                    .tertiary
                    .withAlpha(30),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 日期范围
          Row(
            children: [
              const Text('日期: ', style: TextStyle(fontSize: 13)),
              InkWell(
                onTap: () async {
                  final range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                    initialDateRange: startDate != null &&
                            endDate != null
                        ? DateTimeRange(
                            start: DateTime.parse(startDate!),
                            end: DateTime.parse(endDate!),
                          )
                        : null,
                  );
                  if (range != null) {
                    onDateRangeChanged(
                      DateFormat('yyyy-MM-dd').format(range.start),
                      DateFormat('yyyy-MM-dd').format(range.end),
                    );
                  }
                },
                child: Chip(
                  label: Text(
                    startDate != null && endDate != null
                        ? '$startDate ~ $endDate'
                        : '选择范围',
                  ),
                  deleteIcon: startDate != null
                      ? const Icon(Icons.close, size: 16)
                      : null,
                  onDeleted: startDate != null
                      ? () => onDateRangeChanged(null, null)
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // 金额范围
          Row(
            children: [
              const Text('金额: ', style: TextStyle(fontSize: 13)),
              SizedBox(
                width: 80,
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: '最低',
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  ),
                  keyboardType: TextInputType.number,
                  controller: TextEditingController(text: minAmount),
                  onChanged: onMinAmountChanged,
                ),
              ),
              const Text(' - '),
              SizedBox(
                width: 80,
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: '最高',
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  ),
                  keyboardType: TextInputType.number,
                  controller: TextEditingController(text: maxAmount),
                  onChanged: onMaxAmountChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 账户 & 分类
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: accountId,
                  decoration: const InputDecoration(
                    labelText: '账户',
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('全部')),
                    ...provider.allAccounts.map((a) =>
                        DropdownMenuItem(
                            value: a.id, child: Text(a.name))),
                  ],
                  onChanged: onAccountChanged,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: categoryId,
                  decoration: const InputDecoration(
                    labelText: '分类',
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('全部')),
                    ...provider.categories.map((c) =>
                        DropdownMenuItem(
                            value: c.id, child: Text(c.name))),
                  ],
                  onChanged: onCategoryChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
