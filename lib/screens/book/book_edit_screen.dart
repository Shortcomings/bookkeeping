import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/transaction_provider.dart';
import '../../models/book.dart';

class BookEditScreen extends StatefulWidget {
  final Book? book;
  const BookEditScreen({super.key, this.book});

  @override
  State<BookEditScreen> createState() => _BookEditScreenState();
}

class _BookEditScreenState extends State<BookEditScreen> {
  late String _name;
  late String _color;
  bool _saving = false;
  bool get _isEditing => widget.book != null;

  static const _colors = [
    '0xFF5C6BC0', '0xFF42A5F5', '0xFFEF5350', '0xFF66BB6A',
    '0xFFFFA726', '0xFFAB47BC', '0xFFEC407A', '0xFF78909C',
  ];

  @override
  void initState() {
    super.initState();
    _name = widget.book?.name ?? '';
    _color = widget.book?.color ?? _colors[0];
  }

  Future<void> _save() async {
    if (_name.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入账本名称')));
      return;
    }
    setState(() => _saving = true);
    final provider = context.read<TransactionProvider>();
    try {
      if (_isEditing) {
        await provider.updateBook(widget.book!.copyWith(
            name: _name.trim(), color: _color));
      } else {
        await provider.addBook(name: _name.trim(), color: _color);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? '编辑账本' : '新建账本')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(
          decoration: const InputDecoration(labelText: '账本名称', border: OutlineInputBorder()),
          controller: TextEditingController(text: _name),
          onChanged: (v) => _name = v,
        ),
        const SizedBox(height: 16),
        Text('颜色', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: _colors.map((c) {
          final sel = _color == c;
          return GestureDetector(
            onTap: () => setState(() => _color = c),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: Color(int.parse(c)), shape: BoxShape.circle,
                border: sel ? Border.all(color: Colors.white, width: 3) : null),
              child: sel ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
            ),
          );
        }).toList()),
        const SizedBox(height: 24),
        FilledButton(onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
          child: _saving ? const SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(_isEditing ? '保存' : '创建账本')),
      ]),
    );
  }
}
