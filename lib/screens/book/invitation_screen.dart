import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/transaction_provider.dart';
import '../../models/shared_invitation.dart';

class InvitationScreen extends StatefulWidget {
  final String bookId;
  final String bookName;

  const InvitationScreen({super.key, required this.bookId, required this.bookName});

  @override
  State<InvitationScreen> createState() => _InvitationScreenState();
}

class _InvitationScreenState extends State<InvitationScreen> {
  int _selectedRole = 2;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final invitations = provider.getInvitations(widget.bookId);

    return Scaffold(
      appBar: AppBar(title: Text('${widget.bookName} - 邀请码')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('生成新邀请码', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: '新成员角色', border: OutlineInputBorder()),
                    value: _selectedRole,
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('管理员 — 可管理记录')),
                      DropdownMenuItem(value: 2, child: Text('普通成员 — 仅记账和查看')),
                    ],
                    onChanged: (v) => setState(() => _selectedRole = v ?? 2),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('生成邀请码'),
                      onPressed: () {
                        provider.generateInviteCode(widget.bookId, _selectedRole);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (invitations.isEmpty)
            const Center(child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('暂无邀请码', style: TextStyle(color: Colors.grey)),
            )),
          ...invitations.map((inv) => _buildInvitationCard(context, provider, inv)),
        ],
      ),
    );
  }

  Widget _buildInvitationCard(BuildContext context, TransactionProvider provider, SharedInvitation inv) {
    final roleLabel = inv.role == 1 ? '管理员' : '普通成员';
    final isExpired = inv.isExpired;
    final isActive = inv.isActive && !isExpired;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          isActive ? Icons.vpn_key : Icons.vpn_key_off,
          color: isActive ? Theme.of(context).colorScheme.primary : Colors.grey,
        ),
        title: Text(inv.code, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 4)),
        subtitle: Text('角色: $roleLabel  ·  创建于 ${inv.createdAt.substring(0, 10)}${isExpired ? "  ·  已过期" : ""}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isActive)
              IconButton(
                icon: const Icon(Icons.copy, size: 18),
                tooltip: '复制邀请码',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: inv.code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('邀请码已复制到剪贴板')),
                  );
                },
              ),
            if (isActive)
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: Colors.red),
                tooltip: '停用',
                onPressed: () => provider.deleteInvitation(inv.id, widget.bookId),
              ),
          ],
        ),
      ),
    );
  }
}
