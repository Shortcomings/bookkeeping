import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/transaction_provider.dart';
import '../../models/shared_audit_log.dart';

class AuditLogScreen extends StatelessWidget {
  final String bookId;
  final String bookName;

  const AuditLogScreen({super.key, required this.bookId, required this.bookName});

  IconData _actionIcon(String action) {
    switch (action) {
      case 'create_transaction':
      case 'update_transaction':
      case 'delete_transaction':
        return Icons.receipt_long;
      case 'add_member':
      case 'remove_member':
      case 'update_member_role':
      case 'join_book':
        return Icons.person;
      case 'create_book':
        return Icons.book;
      default:
        return Icons.info_outline;
    }
  }

  Color _actionColor(String action) {
    switch (action) {
      case 'create_transaction':
      case 'add_member':
      case 'join_book':
      case 'create_book':
        return Colors.green;
      case 'update_transaction':
      case 'update_member_role':
        return Colors.blue;
      case 'delete_transaction':
      case 'remove_member':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final logs = provider.getAuditLogs(bookId);

    return Scaffold(
      appBar: AppBar(title: Text('$bookName - 操作日志')),
      body: logs.isEmpty
          ? const Center(child: Text('暂无操作记录', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: logs.length,
              itemBuilder: (context, index) {
                final log = logs[index];
                return _buildLogItem(context, log, index, logs.length);
              },
            ),
    );
  }

  Widget _buildLogItem(BuildContext context, SharedAuditLog log, int index, int total) {
    final color = _actionColor(log.action);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline
        SizedBox(
          width: 32,
          child: Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withOpacity(0.3), width: 2),
                ),
              ),
              if (index < total - 1)
                Container(width: 2, height: 60, color: Colors.grey.shade200),
            ],
          ),
        ),
        // Content
        Expanded(
          child: Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_actionIcon(log.action), size: 16, color: color),
                      const SizedBox(width: 6),
                      Text(
                        log.memberName,
                        style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    log.detail ?? log.action,
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatTime(log.createdAt),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} $h:$m';
    } catch (_) {
      return iso;
    }
  }
}
