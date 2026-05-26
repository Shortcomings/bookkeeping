import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/transaction_provider.dart';
import 'nlp_parser.dart';

class ImportFieldMapping {
  int? dateCol;
  int? typeCol;
  int? amountCol;
  int? categoryCol;
  int? noteCol;
  int? accountCol;
  int? timeCol; // for combined "交易时间" column

  bool get isValid => dateCol != null && amountCol != null;

  Map<String, dynamic> toJson() => {
        'dateCol': dateCol,
        'timeCol': timeCol,
        'typeCol': typeCol,
        'amountCol': amountCol,
        'categoryCol': categoryCol,
        'noteCol': noteCol,
        'accountCol': accountCol,
      };
}

class ImportPreviewRow {
  final int sourceRowIndex;
  final Map<int, String> cells;
  final ImportFieldMapping mapping;
  bool selected = true;
  String? warning;
  String? matchedCategory;
  int? matchedType;

  ImportPreviewRow({
    required this.sourceRowIndex,
    required this.cells,
    required this.mapping,
  });

  String? get date => _cell(mapping.dateCol) ?? _cell(mapping.timeCol);
  String? get amountStr => _cell(mapping.amountCol);
  String? get typeStr => _cell(mapping.typeCol);
  String? get categoryStr => _cell(mapping.categoryCol);
  String? get noteStr => _cell(mapping.noteCol);
  String? get accountStr => _cell(mapping.accountCol);

  String? _cell(int? col) {
    if (col == null) return null;
    final v = cells[col];
    return (v == null || v.trim().isEmpty) ? null : v.trim();
  }
}

class ImportService {
  // ── WeChat bill header patterns ──
  static const _wechatHeaderPatterns = {
    'date': ['交易时间', '交易日期'],
    'type': ['收/支', '收支类型'],
    'amount': ['金额(元)', '金额'],
    'counterparty': ['交易对方', '商户'],
    'product': ['商品', '商品说明'],
    'source': ['支付方式'],
    'status': ['当前状态'],
    'note': ['备注'],
    'orderNo': ['交易单号'],
  };

  // ── Alipay bill header patterns ──
  static const _alipayHeaderPatterns = {
    'date': ['交易创建时间', '付款时间', '交易时间'],
    'type': ['收/支', '类型'],
    'amount': ['金额(元)', '金额'],
    'counterparty': ['交易对方'],
    'product': ['商品名称', '商品说明'],
    'status': ['交易状态', '资金状态'],
    'note': ['备注'],
    'orderNo': ['交易号', '商家订单号'],
  };

  static bool _containsAny(String text, List<String> patterns) {
    final lower = text.toLowerCase();
    return patterns.any((p) => lower.contains(p.toLowerCase()));
  }

  /// Auto-detect template based on headers. Returns 'wechat', 'alipay', or null.
  static String? detectTemplate(List<String> headers) {
    if (headers.isEmpty) return null;

    bool matchWechat = true;
    for (final p in _wechatHeaderPatterns.values) {
      if (!p.any((h) => headers.any((x) => x.trim() == h))) {
        // At least match date + type + amount
        if (p == _wechatHeaderPatterns['date'] ||
            p == _wechatHeaderPatterns['amount']) {
          if (!p.any((h) => headers.any((x) => x.trim() == h))) {
            matchWechat = false;
            break;
          }
        }
      }
    }
    if (matchWechat) return 'wechat';

    bool matchAlipay = true;
    for (final p in _alipayHeaderPatterns.values) {
      if (!p.any((h) => headers.any((x) => x.trim() == h))) {
        if (p == _alipayHeaderPatterns['date'] ||
            p == _alipayHeaderPatterns['amount']) {
          if (!p.any((h) => headers.any((x) => x.trim() == h))) {
            matchAlipay = false;
            break;
          }
        }
      }
    }
    if (matchAlipay) return 'alipay';

    return null;
  }

  /// Auto-map columns using fuzzy matching.
  static ImportFieldMapping autoMapColumns(List<String> headers) {
    final mapping = ImportFieldMapping();
    final datePatterns = [
      '日期', '时间', '交易时间', '创建时间', '付款时间', 'date', 'time', '日付'
    ];
    final typePatterns = [
      '收/支', '收支', '类型', '方向', 'type', '入出金'
    ];
    final amountPatterns = [
      '金额', '元', 'amount', '価格', '価額', '价格', '收入', '支出'
    ];
    final categoryPatterns = [
      '分类', '类别', 'category', 'カテゴリ', '種類', '标签'
    ];
    final notePatterns = [
      '备注', '说明', '描述', 'note', 'remark', 'description', '摘要', '事由'
    ];
    final accountPatterns = [
      '账户', '账号', '支付方式', '银行卡', 'account', '支払方法', '来源'
    ];

    for (var i = 0; i < headers.length; i++) {
      final h = headers[i].trim();
      if (mapping.dateCol == null && _containsAny(h, datePatterns)) {
        mapping.dateCol = i;
      } else if (mapping.typeCol == null && _containsAny(h, typePatterns)) {
        mapping.typeCol = i;
      } else if (mapping.amountCol == null && _containsAny(h, amountPatterns)) {
        mapping.amountCol = i;
      } else if (mapping.noteCol == null && _containsAny(h, notePatterns)) {
        mapping.noteCol = i;
      } else if (mapping.accountCol == null &&
          _containsAny(h, accountPatterns)) {
        mapping.accountCol = i;
      } else if (mapping.categoryCol == null &&
          _containsAny(h, categoryPatterns)) {
        mapping.categoryCol = i;
      }
    }

    return mapping;
  }

  /// Create mapping from a named template.
  static ImportFieldMapping? templateMapping(
      String templateName, List<String> headers) {
    final patterns = templateName == 'wechat'
        ? _wechatHeaderPatterns
        : templateName == 'alipay'
            ? _alipayHeaderPatterns
            : null;
    if (patterns == null) return null;

    final m = ImportFieldMapping();
    for (var i = 0; i < headers.length; i++) {
      final h = headers[i].trim();
      if (m.dateCol == null && patterns['date']!.contains(h)) {
        m.dateCol = i;
      } else if (m.typeCol == null && patterns['type']!.contains(h)) {
        m.typeCol = i;
      } else if (m.amountCol == null && patterns['amount']!.contains(h)) {
        m.amountCol = i;
      } else if (m.noteCol == null && patterns['note']!.contains(h)) {
        m.noteCol = i;
      }
    }
    return m;
  }

  /// Pick a file and parse it. Returns headers + raw rows (excluding header).
  static Future<({String fileName, List<String> headers, List<List<String>> rows, String? template})?>
      pickAndParseFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx', 'xls'],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    final path = file.path;
    final name = file.name;
    if (path == null) return null;

    if (name.endsWith('.csv')) {
      return _parseCsv(path, name);
    } else if (name.endsWith('.xlsx') || name.endsWith('.xls')) {
      return _parseExcel(path, name);
    }
    return null;
  }

  static Future<({String fileName, List<String> headers, List<List<String>> rows, String? template})>
      _parseCsv(String path, String name) async {
    final bytes = await File(path).readAsBytes();
    String content;
    try {
      content = utf8.decode(bytes);
    } catch (_) {
      // Fallback: allow malformed UTF-8 (handles mixed encodings)
      content = utf8.decode(bytes, allowMalformed: true);
    }
    final parsed = const CsvToListConverter(eol: '\n').convert(content);

    if (parsed.isEmpty) {
      return (fileName: name, headers: <String>[], rows: <List<String>>[], template: null);
    }

    final headers = parsed.first.map((e) => e.toString().trim()).toList();
    final template = detectTemplate(headers);

    final rows = parsed.skip(1).map((row) {
      return row.map((e) => e.toString().trim()).toList();
    }).where((row) {
      // Skip completely empty rows
      return row.any((c) => c.isNotEmpty);
    }).toList();

    return (fileName: name, headers: headers, rows: rows, template: template);
  }

  static Future<({String fileName, List<String> headers, List<List<String>> rows, String? template})>
      _parseExcel(String path, String name) async {
    final bytes = await File(path).readAsBytes();
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.tables.keys.firstOrNull;
    if (sheet == null) {
      return (fileName: name, headers: <String>[], rows: <List<String>>[], template: null);
    }

    final table = excel.tables[sheet]!;
    if (table.rows.isEmpty) {
      return (fileName: name, headers: <String>[], rows: <List<String>>[], template: null);
    }

    final headers = table.rows.first
        .map((cell) => (cell?.value?.toString() ?? '').trim())
        .toList();
    final template = detectTemplate(headers);

    final rows = table.rows.skip(1).map((row) {
      return List.generate(headers.length, (i) {
        if (i < row.length) {
          return (row[i]?.value?.toString() ?? '').trim();
        }
        return '';
      });
    }).where((row) {
      return row.any((c) => c.isNotEmpty);
    }).toList();

    return (fileName: name, headers: headers, rows: rows, template: template);
  }

  /// Build preview rows with category matching from a parsed file.
  static List<ImportPreviewRow> buildPreview({
    required List<String> headers,
    required List<List<String>> rows,
    required ImportFieldMapping mapping,
  }) {
    final previewRows = <ImportPreviewRow>[];
    final seen = <String>{};

    for (var i = 0; i < rows.length; i++) {
      final cellMap = <int, String>{};
      for (var j = 0; j < rows[i].length && j < headers.length; j++) {
        cellMap[j] = rows[i][j];
      }
      final preview = ImportPreviewRow(
        sourceRowIndex: i,
        cells: cellMap,
        mapping: mapping,
      );

      // Validate
      if (preview.date == null) {
        preview.warning = '缺少日期';
      } else if (!_isValidDate(preview.date!)) {
        preview.warning = '日期格式无效';
      }

      if (preview.amountStr == null) {
        preview.warning = (preview.warning != null)
            ? '${preview.warning}; 缺少金额'
            : '缺少金额';
      } else if (_parseAmount(preview.amountStr!) == null) {
        preview.warning = (preview.warning != null)
            ? '${preview.warning}; 金额解析失败'
            : '金额解析失败';
      }

      // Dedup check
      final dedupKey = '${preview.date}|${preview.amountStr}|${preview.noteStr ?? ''}';
      if (seen.contains(dedupKey)) {
        preview.warning =
            (preview.warning != null) ? '${preview.warning}; 重复' : '重复';
        preview.selected = false;
      }
      seen.add(dedupKey);

      // Category auto-match from note/merchant name
      final matchText = preview.noteStr ?? preview.categoryStr ?? '';
      if (matchText.isNotEmpty) {
        final match = NlpParser.matchCategoryFromText(matchText);
        preview.matchedCategory = match.categoryName;
        preview.matchedType = match.type;
      }

      previewRows.add(preview);
    }

    return previewRows;
  }

  /// Import selected preview rows into the provider.
  /// Uses importAutoTransaction which handles category matching, dedup, and account selection.
  static Future<int> executeImport({
    required TransactionProvider provider,
    required List<ImportPreviewRow> previewRows,
    required ImportFieldMapping mapping,
  }) async {
    int count = 0;
    for (final row in previewRows.where((r) => r.selected)) {
      final date = _normalizeDate(row.date ?? '');
      final amountCents = _parseAmount(row.amountStr ?? '');
      if (date.isEmpty || amountCents == null) continue;

      int type = 0;
      if (row.typeStr != null) {
        final ts = row.typeStr!.trim();
        if (ts.contains('收入') ||
            ts.contains('入账') ||
            ts.contains('收款') ||
            ts == '收' ||
            ts.contains('income')) {
          type = 1;
        }
      }

      final note = row.noteStr ?? row.categoryStr ?? '导入数据';
      final success = await provider.importAutoTransaction(
        merchantName: note.length > 30 ? note.substring(0, 30) : note,
        amountCents: amountCents,
        type: type,
        date: date,
        sourceApp: '文件导入',
      );
      if (success) count++;
    }
    return count;
  }

  static int? _parseAmount(String s) {
    final cleaned = s.replaceAll(RegExp(r'[^\d.\-]'), '').trim();
    if (cleaned.isEmpty) return null;
    final d = double.tryParse(cleaned);
    if (d == null) return null;
    return (d.abs() * 100).round();
  }

  static bool _isValidDate(String s) {
    return _normalizeDate(s).isNotEmpty;
  }

  static String _normalizeDate(String s) {
    final cleaned = s.trim();
    if (cleaned.isEmpty) return '';

    // Try yyyy-MM-dd, yyyy/MM/dd, yyyy.MM.dd
    for (final sep in ['-', '/', '.']) {
      final parts = cleaned.split(sep);
      if (parts.length == 3) {
        final y = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final d = int.tryParse(parts[2]);
        if (y != null && m != null && d != null && m >= 1 && m <= 12) {
          final lastDay = DateTime(y, m + 1 > 12 ? 1 : m + 1, 0).day;
          final day = d.clamp(1, lastDay);
          return '${y.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
        }
      }
    }

    // Try MM/dd/yyyy
    final dateMatch = RegExp(r'(\d{1,2})[/\-\.](\d{1,2})[/\-\.](\d{4})').firstMatch(cleaned);
    if (dateMatch != null) {
      final m = int.parse(dateMatch.group(1)!);
      final d = int.parse(dateMatch.group(2)!);
      final y = int.parse(dateMatch.group(3)!);
      if (m >= 1 && m <= 12) {
        return '$y-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
      }
    }

    // Try datetime string: "2024-01-15 10:30:00"
    final dtMatch = RegExp(r'(\d{4})[/\-\.](\d{1,2})[/\-\.](\d{1,2})').firstMatch(cleaned);
    if (dtMatch != null) {
      final y = int.parse(dtMatch.group(1)!);
      final m = int.parse(dtMatch.group(2)!);
      final d = int.parse(dtMatch.group(3)!);
      if (m >= 1 && m <= 12) {
        return '$y-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
      }
    }

    return '';
  }

}
