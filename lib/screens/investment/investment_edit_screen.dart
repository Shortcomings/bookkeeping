import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/transaction_provider.dart';
import '../../models/investment.dart';

class InvestmentEditScreen extends StatefulWidget {
  final Investment? investment;
  const InvestmentEditScreen({super.key, this.investment});

  @override
  State<InvestmentEditScreen> createState() => _InvestmentEditScreenState();
}

class _InvestmentEditScreenState extends State<InvestmentEditScreen> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _code = '';
  int _type = 0; // 0=stock, 1=fund, 2=crypto, 3=deposit
  String _sharesStr = ''; // user-entered shares (可小数)
  String _costStr = ''; // user-entered cost in yuan
  String _valueStr = ''; // user-entered market value in yuan
  String _note = '';
  bool _saving = false;

  bool get _isEditing => widget.investment != null;
  final _types = ['股票', '基金', '数字货币', '定期'];

  @override
  void initState() {
    super.initState();
    if (widget.investment != null) {
      final inv = widget.investment!;
      _name = inv.name;
      _code = inv.code ?? '';
      _type = inv.type;
      _sharesStr = (inv.shares / 1000).toStringAsFixed(inv.shares % 1000 == 0 ? 0 : 3);
      _costStr = (inv.costBasis / 100).toStringAsFixed(2);
      _valueStr = (inv.currentValue / 100).toStringAsFixed(2);
      _note = inv.note ?? '';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_name.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入名称')));
      return;
    }

    final shares = ((double.tryParse(_sharesStr) ?? 0) * 1000).round();
    final costBasis = ((double.tryParse(_costStr) ?? 0) * 100).round();
    final currentValue = ((double.tryParse(_valueStr) ?? 0) * 100).round();

    if (shares <= 0 && _type < 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入有效股数')));
      return;
    }
    if (costBasis <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入有效成本')));
      return;
    }

    setState(() => _saving = true);
    final provider = context.read<TransactionProvider>();

    try {
      if (_isEditing) {
        await provider.updateInvestment(widget.investment!.copyWith(
          name: _name.trim(),
          code: _code.isNotEmpty ? _code.trim() : null,
          type: _type,
          shares: shares,
          costBasis: costBasis,
          currentValue: currentValue,
          note: _note.isNotEmpty ? _note : null,
          updatedAt: DateTime.now().toIso8601String(),
        ));
      } else {
        // 查找或创建投资账户
        String accountId;
        final invAccounts = provider.allAccounts.where((a) => a.type == 4).toList();
        if (invAccounts.isNotEmpty) {
          accountId = invAccounts.first.id;
        } else {
          await provider.addAccount(name: '投资账户', type: 4, icon: '0xe227', color: '0xFF0097A7');
          accountId = provider.allAccounts.firstWhere((a) => a.type == 4).id;
        }

        await provider.addInvestment(
          accountId: accountId,
          name: _name.trim(),
          code: _code.isNotEmpty ? _code.trim() : null,
          type: _type,
          shares: shares,
          costBasis: costBasis,
          currentValue: currentValue,
          note: _note.isNotEmpty ? _note : null,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? '编辑持仓' : '添加持仓')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              initialValue: _name,
              decoration: const InputDecoration(labelText: '名称 *', hintText: '如：茅台、沪深300', border: OutlineInputBorder()),
              onChanged: (v) => _name = v,
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _code,
              decoration: const InputDecoration(labelText: '代码', hintText: '如：600519', border: OutlineInputBorder()),
              onChanged: (v) => _code = v,
            ),
            const SizedBox(height: 12),
            Text('投资类型', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: List.generate(_types.length, (i) => ChoiceChip(
              label: Text(_types[i]),
              selected: _type == i,
              onSelected: (_) => setState(() => _type = i),
            ))),
            const SizedBox(height: 12),
            if (_type < 3)
              TextFormField(
                initialValue: _sharesStr,
                decoration: const InputDecoration(labelText: '持有数量（股/份）', hintText: '如：100', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                onChanged: (v) => _sharesStr = v,
              ),
            if (_type < 3) const SizedBox(height: 12),
            TextFormField(
              initialValue: _costStr,
              decoration: InputDecoration(labelText: _type == 3 ? '本金金额' : '持仓成本', prefixText: '¥ ', hintText: '0.00', border: const OutlineInputBorder()),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) => _costStr = v,
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _valueStr,
              decoration: InputDecoration(labelText: _type == 3 ? '到期本息' : '当前市值', prefixText: '¥ ', hintText: '0.00', border: const OutlineInputBorder()),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) => _valueStr = v,
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _note,
              decoration: const InputDecoration(labelText: '备注', border: OutlineInputBorder()),
              onChanged: (v) => _note = v,
              maxLength: 100,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
              child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}
