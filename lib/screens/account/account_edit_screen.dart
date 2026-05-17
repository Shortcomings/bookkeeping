import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/transaction_provider.dart';
import '../../models/account.dart';

class AccountEditScreen extends StatefulWidget {
  final Account? account;
  const AccountEditScreen({super.key, this.account});

  @override
  State<AccountEditScreen> createState() => _AccountEditScreenState();
}

class _AccountEditScreenState extends State<AccountEditScreen> {
  late String _name;
  late int _type;
  late String _icon;
  late String _color;
  String _balance = '0';
  int? _creditLimit;
  int? _billDate;
  int? _dueDate;
  bool _saving = false;

  bool get _isEditing => widget.account != null;
  bool get _isCreditCard => _type == 2;

  static const _typeNames = ['现金', '借记卡', '信用卡', '储值卡', '投资'];
  static const _typeIcons = [
    Icons.money, Icons.credit_card, Icons.credit_score,
    Icons.account_balance_wallet, Icons.trending_up,
  ];

  static const _colors = [
    '0xFF5C6BC0', '0xFF42A5F5', '0xFFEF5350', '0xFF66BB6A',
    '0xFFFFA726', '0xFFAB47BC', '0xFFEC407A', '0xFF78909C',
  ];

  @override
  void initState() {
    super.initState();
    final a = widget.account;
    _name = a?.name ?? '';
    _type = a?.type ?? 0;
    _icon = a?.icon ?? '0xe3c8';
    _color = a?.color ?? _colors[0];
    _balance = a != null ? (a.balance / 100).toStringAsFixed(2) : '0';
    _creditLimit = a?.creditLimit;
    _billDate = a?.billDate;
    _dueDate = a?.dueDate;
  }

  Future<void> _save() async {
    if (_name.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入账户名称')),
      );
      return;
    }
    final balanceInCents =
        (double.tryParse(_balance) ?? 0 * 100).round();

    setState(() => _saving = true);
    final provider = context.read<TransactionProvider>();

    try {
      if (_isEditing) {
        await provider.updateAccount(widget.account!.copyWith(
          name: _name.trim(),
          type: _type,
          icon: _icon,
          color: _color,
          balance: balanceInCents,
          creditLimit: _isCreditCard ? _creditLimit : null,
          billDate: _isCreditCard ? _billDate : null,
          dueDate: _isCreditCard ? _dueDate : null,
        ));
      } else {
        await provider.addAccount(
          name: _name.trim(),
          type: _type,
          icon: _icon,
          color: _color,
          balance: balanceInCents,
          creditLimit: _isCreditCard ? _creditLimit : null,
          billDate: _isCreditCard ? _billDate : null,
          dueDate: _isCreditCard ? _dueDate : null,
        );
      }
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑账户' : '添加账户'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            decoration: const InputDecoration(
              labelText: '账户名称',
              border: OutlineInputBorder(),
            ),
            controller: TextEditingController(text: _name),
            onChanged: (v) => _name = v,
          ),
          const SizedBox(height: 16),

          // 类型选择
          Text('账户类型', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: List.generate(5, (i) {
              final selected = _type == i;
              return ChoiceChip(
                label: Text(_typeNames[i]),
                avatar: Icon(_typeIcons[i], size: 18),
                selected: selected,
                onSelected: (_) => setState(() => _type = i),
              );
            }),
          ),
          const SizedBox(height: 16),

          // 余额
          TextField(
            decoration: const InputDecoration(
              labelText: '当前余额',
              prefixText: '¥ ',
              border: OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            controller: TextEditingController(text: _balance),
            onChanged: (v) => _balance = v,
          ),
          const SizedBox(height: 16),

          // 信用卡专属字段
          if (_isCreditCard) ...[
            const Divider(),
            Text('信用卡信息',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                labelText: '信用额度',
                prefixText: '¥ ',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              controller: TextEditingController(
                  text: _creditLimit != null
                      ? (_creditLimit! / 100).toStringAsFixed(0)
                      : ''),
              onChanged: (v) =>
                  _creditLimit = (double.tryParse(v) ?? 0 * 100).round(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _DayPicker(
                    label: '账单日',
                    value: _billDate,
                    max: 28,
                    onChanged: (v) => setState(() => _billDate = v),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _DayPicker(
                    label: '还款日',
                    value: _dueDate,
                    max: 31,
                    onChanged: (v) => setState(() => _dueDate = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // 颜色
          Text('颜色', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _colors.map((c) {
              final selected = _color == c;
              return GestureDetector(
                onTap: () => setState(() => _color = c),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Color(int.parse(c)),
                    shape: BoxShape.circle,
                    border: selected
                        ? Border.all(color: Colors.white, width: 3)
                        : null,
                  ),
                  child: selected
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

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
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(_isEditing ? '保存修改' : '添加账户'),
          ),
        ],
      ),
    );
  }
}

class _DayPicker extends StatelessWidget {
  final String label;
  final int? value;
  final int max;
  final ValueChanged<int?> onChanged;

  const _DayPicker({
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final items = List.generate(max, (i) => i + 1);
    return DropdownButtonFormField<int>(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      value: value,
      items: [
        const DropdownMenuItem(value: null, child: Text('未设置')),
        ...items.map((d) => DropdownMenuItem(value: d, child: Text('$d号'))),
      ],
      onChanged: onChanged,
    );
  }
}
