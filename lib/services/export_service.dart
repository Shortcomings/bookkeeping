import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import '../providers/transaction_provider.dart';

class ExportService {
  static Future<void> exportToCsv(
    TransactionProvider provider, {
    String? startDate,
    String? endDate,
  }) async {
    final currencyFormat = NumberFormat.currency(symbol: '¥', decimalDigits: 2);
    final txs = provider.searchTransactions(
      startDate: startDate,
      endDate: endDate,
    );

    final rows = <List<String>>[
      ['日期', '类型', '分类', '金额', '账户', '备注'],
    ];

    for (final tx in txs) {
      final cat = provider.getCategoryById(tx.categoryId);
      final account = tx.accountId != null ? provider.getAccountById(tx.accountId!) : null;
      rows.add([
        tx.date,
        tx.type == 0 ? '支出' : '收入',
        cat?.name ?? '未知',
        currencyFormat.format(tx.amount / 100),
        account?.name ?? '',
        tx.note ?? '',
      ]);
    }

    final csvData = const ListToCsvConverter().convert(rows);
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/记账导出_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv');
    await file.writeAsString(csvData);

    await Share.shareXFiles([XFile(file.path)], text: '记账数据导出');
  }

  static Future<void> exportAdvancedReport(
    TransactionProvider provider,
  ) async {
    final currencyFormat = NumberFormat.currency(symbol: '¥', decimalDigits: 2);
    final cashFlow = provider.getMonthlyCashFlow();

    final rows = <List<String>>[
      ['高级报表'],
      [],
      ['资产负债表'],
      ['项目', '金额'],
      ['总资产', currencyFormat.format(provider.totalInvestmentValue / 100 + provider.allAccounts.where((a) => a.type != 4).fold<int>(0, (s, a) => s + (a.balance > 0 ? a.balance : 0)) / 100)],
    ];

    for (final a in provider.allAccounts) {
      if (a.type != 4) {
        final names = ['现金', '借记卡', '信用卡', '储值卡', '投资'];
        rows.add([names[a.type.clamp(0, 4)], currencyFormat.format(a.balance / 100)]);
      }
    }
    rows.add(['投资市值', currencyFormat.format(provider.totalInvestmentValue / 100)]);
    rows.add([]);
    rows.add(['现金流表']);
    rows.add(['月份', '收入', '支出', '净现金流']);
    for (final cf in cashFlow) {
      rows.add([cf.month, currencyFormat.format(cf.income / 100), currencyFormat.format(cf.expense / 100), currencyFormat.format(cf.net / 100)]);
    }

    final csvData = const ListToCsvConverter().convert(rows);
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/高级报表_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv');
    await file.writeAsString(csvData);

    await Share.shareXFiles([XFile(file.path)], text: '高级报表');
  }
}
