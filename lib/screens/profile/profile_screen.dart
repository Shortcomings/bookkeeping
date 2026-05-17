import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../providers/transaction_provider.dart';
import '../../models/transaction.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> _showExportOptions(BuildContext context) async {
    final provider = context.read<TransactionProvider>();

    // Date range picker
    DateTimeRange? range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 30)),
        end: DateTime.now(),
      ),
      helpText: '选择导出时间范围',
      cancelText: '取消',
      confirmText: '确定',
    );

    if (range == null || !context.mounted) return;

    final startDate = DateFormat('yyyy-MM-dd').format(range.start);
    final endDate = DateFormat('yyyy-MM-dd').format(range.end);

    final filtered = provider.transactions
        .where((t) =>
            t.date.compareTo(startDate) >= 0 && t.date.compareTo(endDate) <= 0)
        .toList();

    if (filtered.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('所选时间范围内无记录')),
        );
      }
      return;
    }

    // Show format picker
    if (!context.mounted) return;
    final format = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('选择导出格式'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.table_chart_outlined),
              title: const Text('Excel (.xlsx)'),
              subtitle: const Text('适合在电脑上查看和编辑'),
              onTap: () => Navigator.pop(ctx, 'excel'),
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('CSV (.csv)'),
              subtitle: const Text('通用格式，兼容性最好'),
              onTap: () => Navigator.pop(ctx, 'csv'),
            ),
          ],
        ),
      ),
    );

    if (format == null || !context.mounted) return;

    if (format == 'excel') {
      await _exportExcel(context, filtered, startDate, endDate);
    } else {
      await _exportCsv(context, filtered, startDate, endDate);
    }
  }

  Future<void> _exportExcel(BuildContext context, List<Transaction> txs,
      String startDate, String endDate) async {
    final provider = context.read<TransactionProvider>();

    final excel = Excel.createExcel();
    final sheet = excel['账单导出'];

    sheet.appendRow([
      const TextCellValue('日期'),
      const TextCellValue('类型'),
      const TextCellValue('分类'),
      const TextCellValue('金额(元)'),
      const TextCellValue('账户'),
      const TextCellValue('备注'),
    ]);

    for (final tx in txs) {
      final cat = provider.getCategoryById(tx.categoryId);
      final acc = tx.accountId != null ? provider.getAccountById(tx.accountId!) : null;
      sheet.appendRow([
        TextCellValue(tx.date),
        TextCellValue(tx.type == 0 ? '支出' : '收入'),
        TextCellValue(cat?.name ?? '未知'),
        DoubleCellValue(tx.amount / 100),
        TextCellValue(acc?.name ?? ''),
        TextCellValue(tx.note ?? ''),
      ]);
    }

    final dir = await getApplicationDocumentsDirectory();
    final file = File(
        '${dir.path}/记账导出_${startDate}_${endDate}.xlsx');
    await file.writeAsBytes(excel.encode()!);

    if (context.mounted) {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)]),
      );
    }
  }

  Future<void> _exportCsv(BuildContext context, List<Transaction> txs,
      String startDate, String endDate) async {
    final provider = context.read<TransactionProvider>();

    final rows = <List<String>>[
      ['日期', '类型', '分类', '金额(元)', '账户', '备注'],
    ];

    for (final tx in txs) {
      final cat = provider.getCategoryById(tx.categoryId);
      final acc = tx.accountId != null ? provider.getAccountById(tx.accountId!) : null;
      rows.add([
        tx.date,
        tx.type == 0 ? '支出' : '收入',
        cat?.name ?? '未知',
        (tx.amount / 100).toStringAsFixed(2),
        acc?.name ?? '',
        tx.note ?? '',
      ]);
    }

    final csvString = const ListToCsvConverter().convert(rows);
    final dir = await getApplicationDocumentsDirectory();
    final file = File(
        '${dir.path}/记账导出_${startDate}_${endDate}.csv');
    await file.writeAsString(csvString);

    if (context.mounted) {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)]),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final totalCount = provider.transactions.length;

    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(Icons.person,
                        color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('记账用户',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text('共 $totalCount 条记录',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text('数据管理',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.file_download_outlined),
                  title: const Text('导出数据'),
                  subtitle: const Text('支持 Excel / CSV 格式，可按时间范围导出'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showExportOptions(context),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('关于'),
                  subtitle: const Text('版本 1.0.0'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
