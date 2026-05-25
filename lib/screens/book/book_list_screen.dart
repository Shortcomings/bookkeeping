import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/transaction_provider.dart';
import '../../models/book.dart';
import 'book_edit_screen.dart';

class BookListScreen extends StatelessWidget {
  const BookListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final books = provider.books;
    final currentId = provider.currentBookId;

    return Scaffold(
      appBar: AppBar(title: const Text('账本管理')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: books.length,
        itemBuilder: (context, index) {
          final b = books[index];
          final isCurrent = b.id == currentId;
          return Card(
            color: isCurrent ? Theme.of(context).colorScheme.primaryContainer : null,
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Color(int.parse(b.color)),
                radius: 18,
                child: Text(b.name.substring(0, 1),
                    style: const TextStyle(color: Colors.white)),
              ),
              title: Text(b.name, style: const TextStyle(fontSize: 15)),
              subtitle: isCurrent ? const Text('当前账本', style: TextStyle(fontSize: 12)) : null,
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                if (!isCurrent)
                  TextButton(
                    onPressed: () => provider.switchBook(b.id),
                    child: const Text('切换'),
                  ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ChangeNotifierProvider.value(
                        value: provider, child: BookEditScreen(book: b)),
                  )),
                ),
                if (b.id != 'default')
                  IconButton(
                    icon: Icon(Icons.delete_outline, size: 18,
                        color: Theme.of(context).colorScheme.error),
                    onPressed: () => _confirmDelete(context, b),
                  ),
              ]),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'book_fab',
        onPressed: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(
              value: provider, child: const BookEditScreen()),
        )),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Book b) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除账本'),
        content: Text('确定删除「${b.name}」吗？该账本下的所有记录将被永久删除。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              context.read<TransactionProvider>().deleteBook(b.id);
              Navigator.pop(ctx);
            },
            child: Text('删除', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
  }
}
