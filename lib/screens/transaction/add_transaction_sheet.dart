import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/transaction_provider.dart';
import '../../models/account.dart';

class AddTransactionSheet extends StatefulWidget {
  final String? editTransactionId;
  const AddTransactionSheet({super.key, this.editTransactionId});

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  int _type = 0;
  String _amount = '';
  String _categoryId = '';
  String? _accountId;
  String _note = '';
  String _date = '';
  bool _saving = false;

  late TransactionProvider _provider;
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _provider = context.read<TransactionProvider>();
    _date = DateFormat('yyyy-MM-dd').format(DateTime.now());

    if (widget.editTransactionId != null) {
      final tx = _provider.transactions.firstWhere(
        (t) => t.id == widget.editTransactionId,
      );
      _type = tx.type;
      _amount = (tx.amount / 100).toStringAsFixed(2);
      _categoryId = tx.categoryId;
      _accountId = tx.accountId;
      _note = tx.note ?? '';
      _date = tx.date;
    } else {
      final cats = _type == 0 ? _provider.expenseCategories : _provider.incomeCategories;
      if (cats.isNotEmpty) _categoryId = cats.first.id;
      if (_provider.accounts.isNotEmpty) _accountId = _provider.accounts.first.id;
    }
    _amountController.text = _amount;
    _noteController.text = _note;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _switchType(int type) {
    setState(() {
      _type = type;
      final cats = type == 0 ? _provider.expenseCategories : _provider.incomeCategories;
      _categoryId = cats.isNotEmpty ? cats.first.id : '';
    });
  }

  double? _evaluateExpression(String expr) {
    if (expr.isEmpty) return null;
    final cleaned = expr.replaceAll(RegExp(r'[^\d+\-*/.]'), '');
    if (cleaned.isEmpty) return null;
    if (!cleaned.contains(RegExp(r'[+\-*/]'))) return null;
    try {
      return _safeEval(cleaned);
    } catch (_) {
      return null;
    }
  }

  double? _safeEval(String expr) {
    // Simple left-to-right evaluation of + and -
    final parts = <dynamic>[];
    final regex = RegExp(r'(\d+\.?\d*|[+\-])');
    for (final m in regex.allMatches(expr)) {
      final token = m.group(0)!;
      if (token == '+' || token == '-') {
        parts.add(token);
      } else {
        parts.add(double.parse(token));
      }
    }
    if (parts.isEmpty || parts.first is String) return null;
    double result = parts.first as double;
    for (int i = 1; i < parts.length - 1; i += 2) {
      final op = parts[i] as String;
      final val = parts[i + 1] as double;
      if (op == '+') {
        result += val;
      } else if (op == '-') {
        result -= val;
      }
    }
    // Check if there was actual computation
    if (parts.length == 1) return null;
    return result;
  }

  Future<void> _save() async {
    final rawInput = _amount.trim();
    double? parsed;

    // Try expression evaluation first
    final evaluated = _evaluateExpression(rawInput);
    if (evaluated != null) {
      parsed = evaluated;
    } else {
      parsed = double.tryParse(rawInput);
    }

    if (parsed == null || parsed <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效金额')),
      );
      return;
    }
    if (_categoryId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择分类')),
      );
      return;
    }

    setState(() => _saving = true);

    final amountInCents = (parsed * 100).round();

    try {
      if (widget.editTransactionId != null) {
        final oldTx = _provider.transactions.firstWhere(
          (t) => t.id == widget.editTransactionId,
        );
        await _provider.updateTransaction(
          oldTx.copyWith(
            type: _type,
            amount: amountInCents,
            date: _date,
            categoryId: _categoryId,
            accountId: _accountId,
            note: _note.isEmpty ? null : _note,
          ),
        );
      } else {
        await _provider.addTransaction(
          type: _type,
          amount: amountInCents,
          date: _date,
          categoryId: _categoryId,
          accountId: _accountId,
          note: _note.isEmpty ? null : _note,
        );
      }
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cats = _type == 0 ? _provider.expenseCategories : _provider.incomeCategories;
    final evaluated = _evaluateExpression(_amount.trim());
    final accounts = _provider.accounts;
    final selectedAccount = _accountId != null
        ? accounts.firstWhere((a) => a.id == _accountId)
        : null;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 拖拽条
          Center(
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline.withAlpha(80),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 标题
          Text(
            widget.editTransactionId != null ? '编辑记录' : '记一笔',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          // 收/支切换
          Row(
            children: [
              _TypeChip(
                label: '支出',
                selected: _type == 0,
                selectedColor: Theme.of(context).colorScheme.error,
                onTap: () => _switchType(0),
              ),
              const SizedBox(width: 8),
              _TypeChip(
                label: '收入',
                selected: _type == 1,
                selectedColor: Theme.of(context).colorScheme.tertiary,
                onTap: () => _switchType(1),
              ),
              const Spacer(),
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.tryParse(_date) ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (date != null) {
                    setState(() => _date = DateFormat('yyyy-MM-dd').format(date));
                  }
                },
                child: Chip(
                  avatar: const Icon(Icons.calendar_today, size: 16),
                  label: Text(_date),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 金额输入
          TextField(
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            decoration: InputDecoration(
              hintText: '0.00',
              prefixText: '¥ ',
              border: const OutlineInputBorder(),
              suffixText: evaluated != null
                  ? '= ${NumberFormat.currency(symbol: '¥', decimalDigits: 2).format(evaluated)}'
                  : null,
              suffixTextStyle: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            onChanged: (v) => setState(() => _amount = v),
            controller: _amountController,
          ),
          if (evaluated == null && _amount.contains(RegExp(r'[+\-]')))
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 12),
              child: Text(
                '输入表达式如 35+18 自动计算',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ),
          const SizedBox(height: 16),

          // 分类选择
          Text('分类', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: cats.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = cats[index];
                final selected = cat.id == _categoryId;
                return GestureDetector(
                  onTap: () => setState(() => _categoryId = cat.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    child: Column(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: selected
                                ? Color(int.parse(cat.color))
                                : Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            border: selected
                                ? Border.all(
                                    color: Theme.of(context).colorScheme.primary,
                                    width: 2)
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              cat.name.substring(0, 1),
                              style: TextStyle(
                                color: selected
                                    ? Colors.white
                                    : Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 56,
                          child: Text(
                            cat.name,
                            style: Theme.of(context).textTheme.labelSmall,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // 账户选择
          Row(
            children: [
              Text('账户', style: Theme.of(context).textTheme.labelLarge),
              const Spacer(),
              if (accounts.isNotEmpty)
                InkWell(
                  onTap: () => _showAccountPicker(accounts),
                  child: Chip(
                    avatar: CircleAvatar(
                      radius: 10,
                      backgroundColor: selectedAccount != null
                          ? Color(int.parse(selectedAccount.color))
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    label: Text(selectedAccount?.name ?? '选择账户'),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // 备注
          TextField(
            decoration: const InputDecoration(
              hintText: '添加备注...',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => _note = v,
            controller: _noteController,
            maxLength: 200,
          ),
          const SizedBox(height: 16),

          // 保存按钮
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showAccountPicker(List<Account> accounts) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('选择账户',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ...accounts.map((a) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Color(int.parse(a.color)),
                    radius: 16,
                    child: Text(a.name.substring(0, 1),
                        style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                  title: Text(a.name),
                  subtitle: Text(
                    NumberFormat.currency(symbol: '¥', decimalDigits: 2)
                        .format(a.balance / 100),
                  ),
                  selected: a.id == _accountId,
                  onTap: () {
                    setState(() => _accountId = a.id);
                    Navigator.pop(ctx);
                  },
                )),
          ],
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: selectedColor.withAlpha(30),
      labelStyle: TextStyle(
        color: selected
            ? selectedColor
            : Theme.of(context).colorScheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
