import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/transaction_provider.dart';
import '../../models/shared_member.dart';
import 'invitation_screen.dart';

class SharedMembersScreen extends StatefulWidget {
  final String bookId;
  final String bookName;

  const SharedMembersScreen({super.key, required this.bookId, required this.bookName});

  @override
  State<SharedMembersScreen> createState() => _SharedMembersScreenState();
}

class _SharedMembersScreenState extends State<SharedMembersScreen> {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final members = provider.getMembers(widget.bookId);
    final current = provider.currentMember;

    return Scaffold(
      appBar: AppBar(title: Text('${widget.bookName} - 成员管理')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '当前用户: ${provider.currentUserName.isNotEmpty ? provider.currentUserName : "未设置"}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('修改'),
                  onPressed: () => _showNameDialog(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: members.length,
              itemBuilder: (context, index) {
                final m = members[index];
                final isMe = current != null && m.id == current.id;
                final canManage = current != null && current.isCreator;
                final canEditThis = canManage && !m.isCreator;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: m.isCreator
                          ? Colors.amber
                          : m.isAdmin
                              ? Colors.blue
                              : Colors.green,
                      radius: 18,
                      child: Text(
                        m.name.isNotEmpty ? m.name[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(m.name, style: const TextStyle(fontSize: 15)),
                        if (isMe) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('我', style: TextStyle(fontSize: 11)),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Text(m.joinedAt.substring(0, 10), style: const TextStyle(fontSize: 12)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildRoleChip(m),
                        if (canEditThis)
                          PopupMenuButton<int>(
                            onSelected: (v) {
                              if (v == -1) {
                                _confirmRemove(provider, m);
                              } else {
                                provider.updateMemberRole(m.id, widget.bookId, v);
                              }
                            },
                            itemBuilder: (_) => [
                              if (m.role != 1)
                                const PopupMenuItem(value: 1, child: Text('设为管理员')),
                              if (m.role != 2)
                                const PopupMenuItem(value: 2, child: Text('设为普通成员')),
                              const PopupMenuItem(value: -1, child: Text('移除成员', style: TextStyle(color: Colors.red))),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'add_member_invite',
            tooltip: '邀请成员',
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => ChangeNotifierProvider.value(
                value: provider,
                child: InvitationScreen(bookId: widget.bookId, bookName: widget.bookName),
              ),
            )),
            child: const Icon(Icons.link),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'add_member_direct',
            tooltip: '直接添加成员',
            onPressed: () => _showAddMemberDialog(context),
            child: const Icon(Icons.person_add),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleChip(SharedMember m) {
    Color color;
    switch (m.role) {
      case 0:
        color = Colors.amber.shade700;
        break;
      case 1:
        color = Colors.blue;
        break;
      default:
        color = Colors.green;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(m.roleLabel, style: TextStyle(color: color, fontSize: 12)),
    );
  }

  void _showAddMemberDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    int selectedRole = 2;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('添加成员'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: '成员名称', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(labelText: '角色', border: OutlineInputBorder()),
                value: selectedRole,
                items: const [
                  DropdownMenuItem(value: 1, child: Text('管理员')),
                  DropdownMenuItem(value: 2, child: Text('普通成员')),
                ],
                onChanged: (v) => setDialogState(() => selectedRole = v ?? 2),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.trim().isNotEmpty) {
                  context.read<TransactionProvider>().addMember(widget.bookId, nameCtrl.text.trim(), selectedRole);
                  Navigator.pop(ctx);
                }
              },
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
  }

  void _showNameDialog(BuildContext context) {
    final ctrl = TextEditingController(text: context.read<TransactionProvider>().currentUserName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('设置我的名称'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: '你的名称', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                context.read<TransactionProvider>().setCurrentUserName(ctrl.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _confirmRemove(TransactionProvider provider, SharedMember m) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('移除成员'),
        content: Text('确定移除「${m.name}」吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              provider.removeMember(m.id, widget.bookId);
              Navigator.pop(ctx);
            },
            child: const Text('移除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
