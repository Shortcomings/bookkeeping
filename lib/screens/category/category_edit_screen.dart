import 'package:flutter/material.dart' hide Category;
import 'package:provider/provider.dart';
import '../../providers/transaction_provider.dart';
import '../../models/category.dart';

class CategoryEditScreen extends StatefulWidget {
  final Category? category;
  final int? defaultType;
  const CategoryEditScreen({super.key, this.category, this.defaultType});

  @override
  State<CategoryEditScreen> createState() => _CategoryEditScreenState();
}

class _CategoryEditScreenState extends State<CategoryEditScreen> {
  late String _name;
  late int _type;
  late String _icon;
  late String _color;
  String? _parentId;
  bool _saving = false;

  bool get _isEditing => widget.category != null;

  static const _colors = [
    '0xFFFF7043', '0xFF42A5F5', '0xFFAB47BC', '0xFFFFA726',
    '0xFF78909C', '0xFFEF5350', '0xFF66BB6A', '0xFF29B6F6',
    '0xFF8D6E63', '0xFFEC407A', '0xFF5C6BC0', '0xFF43A047',
    '0xFFFDD835', '0xFFE91E63', '0xFF00BCD4', '0xFFFF9800',
  ];

  static const _icons = [
    Icons.fastfood, Icons.directions_car, Icons.shopping_bag,
    Icons.movie, Icons.home, Icons.local_hospital,
    Icons.school, Icons.phone, Icons.cleaning_services,
    Icons.people, Icons.more_horiz, Icons.work,
    Icons.card_giftcard, Icons.trending_up, Icons.money_off,
    Icons.attach_money, Icons.account_balance, Icons.pets,
  ];

  @override
  void initState() {
    super.initState();
    final c = widget.category;
    _name = c?.name ?? '';
    _type = c?.type ?? widget.defaultType ?? 0;
    _icon = c?.icon ?? '0xe5d3';
    _color = c?.color ?? _colors[0];
    _parentId = c?.parentId;
  }

  Future<void> _save() async {
    if (_name.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入分类名称')),
      );
      return;
    }

    setState(() => _saving = true);
    final provider = context.read<TransactionProvider>();

    try {
      if (_isEditing) {
        await provider.updateCategory(
          widget.category!.copyWith(
            name: _name.trim(),
            icon: _icon,
            color: _color,
            parentId: _parentId,
          ),
        );
      } else {
        await provider.addCategory(
          name: _name.trim(),
          type: _type,
          icon: _icon,
          color: _color,
          parentId: _parentId,
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
    final provider = context.watch<TransactionProvider>();
    final parentCandidates = provider.rootCategories
        .where((c) => c.id != widget.category?.id && c.type == _type)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑分类' : '添加分类'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 名称
          TextField(
            decoration: const InputDecoration(
              labelText: '分类名称',
              border: OutlineInputBorder(),
            ),
            controller: TextEditingController(text: _name),
            onChanged: (v) => _name = v,
          ),
          const SizedBox(height: 16),

          // 类型（新建时可切换，编辑时锁定）
          if (!_isEditing) ...[
            Text('类型', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Row(
              children: [
                ChoiceChip(
                  label: const Text('支出'),
                  selected: _type == 0,
                  onSelected: (_) => setState(() {
                    _type = 0;
                    _parentId = null;
                  }),
                  selectedColor: Theme.of(context).colorScheme.error.withAlpha(30),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('收入'),
                  selected: _type == 1,
                  onSelected: (_) => setState(() {
                    _type = 1;
                    _parentId = null;
                  }),
                  selectedColor: Theme.of(context).colorScheme.tertiary.withAlpha(30),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // 父分类
          if (parentCandidates.isNotEmpty) ...[
            Text('父分类（可选）', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('无'),
                  selected: _parentId == null,
                  onSelected: (_) => setState(() => _parentId = null),
                ),
                ...parentCandidates.map((c) => ChoiceChip(
                      label: Text(c.name),
                      selected: _parentId == c.id,
                      onSelected: (_) => setState(() => _parentId = c.id),
                    )),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // 图标选择
          Text('图标', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: _icons.map((icon) {
              final code = '0x${icon.codePoint.toRadixString(16)}';
              final selected = _icon == code;
              return GestureDetector(
                onTap: () => setState(() => _icon = code),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: selected
                        ? Color(int.parse(_color))
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    border: selected
                        ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                        : null,
                  ),
                  child: Icon(icon,
                      size: 20, color: selected ? Colors.white : null),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // 颜色选择
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
                    boxShadow: selected
                        ? [BoxShadow(
                            color: Color(int.parse(c)).withAlpha(100),
                            blurRadius: 8,
                            spreadRadius: 1,
                          )]
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

          // 保存
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
                : Text(_isEditing ? '保存修改' : '添加分类'),
          ),
        ],
      ),
    );
  }
}
