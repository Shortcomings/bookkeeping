import 'package:flutter/material.dart' hide Category;
import 'package:provider/provider.dart';
import '../../providers/transaction_provider.dart';
import '../../models/category.dart';
import 'category_edit_screen.dart';

class CategoryListScreen extends StatelessWidget {
  const CategoryListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final allCats = provider.allCategories;

    final expenseRoots =
        allCats.where((c) => c.type == 0 && c.parentId == null).toList();
    final incomeRoots =
        allCats.where((c) => c.type == 1 && c.parentId == null).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('分类管理')),
      body: allCats.isEmpty
          ? const Center(child: Text('暂无分类'))
          : ReorderableListView(
              padding: const EdgeInsets.all(16),
              onReorder: (oldIndex, newIndex) {
                // Collect all IDs in display order
                final ordered = <String>[];
                for (final r in expenseRoots) {
                  ordered.add(r.id);
                  final children = provider.getChildCategories(r.id);
                  ordered.addAll(children.map((c) => c.id));
                }
                for (final r in incomeRoots) {
                  ordered.add(r.id);
                  final children = provider.getChildCategories(r.id);
                  ordered.addAll(children.map((c) => c.id));
                }
                // Only allow reorder within same section
                final movedId = ordered.removeAt(oldIndex);
                ordered.insert(newIndex, movedId);
                provider.reorderCategories(ordered);
              },
              children: [
                _SectionHeader(title: '支出分类', count: expenseRoots.length),
                ..._buildCategoryGroup(context, provider, expenseRoots, 0),
                const SizedBox(height: 16),
                _SectionHeader(title: '收入分类', count: incomeRoots.length),
                ..._buildCategoryGroup(context, provider, incomeRoots, 1),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider.value(
              value: provider,
              child: const CategoryEditScreen(),
            ),
          ),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  List<Widget> _buildCategoryGroup(BuildContext context,
      TransactionProvider provider, List<Category> roots, int type) {
    final widgets = <Widget>[];
    for (final root in roots) {
      widgets.add(
        _CategoryTile(
          key: Key(root.id),
          category: root,
          isChild: false,
        ),
      );
      final children = provider.getChildCategories(root.id);
      for (final child in children) {
        widgets.add(
          _CategoryTile(
            key: Key(child.id),
            category: child,
            isChild: true,
          ),
        );
      }
    }
    if (widgets.isEmpty) {
      widgets.add(Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          type == 0 ? '暂无支出分类' : '暂无收入分类',
          style: TextStyle(color: Theme.of(context).colorScheme.outline),
        ),
      ));
    }
    return widgets;
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Text('$title · $count',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w600)),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final Category category;
  final bool isChild;

  const _CategoryTile({
    super.key,
    required this.category,
    required this.isChild,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<TransactionProvider>();

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isChild) const SizedBox(width: 32),
            CircleAvatar(
              backgroundColor: Color(int.parse(category.color)),
              radius: 16,
              child: Text(category.name.substring(0, 1),
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ],
        ),
        title: Text(category.name, style: const TextStyle(fontSize: 14)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: category.isEnabled,
              onChanged: (v) =>
                  provider.toggleCategoryEnabled(category.id, v),
            ),
            IconButton(
              icon: const Icon(Icons.edit, size: 18),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChangeNotifierProvider.value(
                    value: provider,
                    child: CategoryEditScreen(category: category),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline,
                  size: 18,
                  color: Theme.of(context).colorScheme.error),
              onPressed: () => _showDeleteDialog(context, category.id),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, String id) {
    final provider = context.read<TransactionProvider>();
    // Check if referenced
    final hasRef = provider.transactions.any((t) => t.categoryId == id);
    if (hasRef) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该分类下已有交易记录，无法删除')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除分类'),
        content: Text('确定删除「${category.name}」吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              provider.deleteCategory(id);
              Navigator.pop(ctx);
            },
            child: Text('删除',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
  }
}
