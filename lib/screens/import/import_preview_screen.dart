import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/import_service.dart';
import '../../providers/transaction_provider.dart';

class ImportPreviewScreen extends StatefulWidget {
  final String fileName;
  final List<String> headers;
  final List<List<String>> rows;
  final String? template;

  const ImportPreviewScreen({
    super.key,
    required this.fileName,
    required this.headers,
    required this.rows,
    this.template,
  });

  @override
  State<ImportPreviewScreen> createState() => _ImportPreviewScreenState();
}

class _ImportPreviewScreenState extends State<ImportPreviewScreen> {
  late ImportFieldMapping _mapping;
  late List<ImportPreviewRow> _previewRows;
  bool _importing = false;
  bool _selectAll = true;

  static const _typeHeaders = ['收/支', '类型', '收支'];
  static const _dateHeaders = ['日期', '时间', '交易时间', '付款时间', '创建时间'];
  static const _amountHeaders = ['金额', '金额(元)', '收入', '支出'];
  static const _noteHeaders = ['备注', '说明', '描述', '摘要'];
  static const _categoryHeaders = ['分类', '类别', '标签'];
  static const _accountHeaders = ['账户', '支付方式', '来源'];

  @override
  void initState() {
    super.initState();
    // Use template if available, otherwise auto-detect
    _mapping = ImportService.templateMapping(
            widget.template ?? '', widget.headers) ??
        ImportService.autoMapColumns(widget.headers);
    _buildPreview();
  }

  void _buildPreview() {
    _previewRows = ImportService.buildPreview(
      headers: widget.headers,
      rows: widget.rows,
      mapping: _mapping,
    );
    _selectAll = _previewRows.every((r) => r.selected);
  }

  Future<void> _doImport() async {
    setState(() => _importing = true);
    final provider = context.read<TransactionProvider>();
    final count = await ImportService.executeImport(
      provider: provider,
      previewRows: _previewRows,
      mapping: _mapping,
    );
    if (!mounted) return;
    Navigator.of(context).pop(count);
  }

  void _showMappingDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('调整列映射'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 400),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildMappingDropdown(setDialogState, '日期列',
                        _mapping.dateCol, _dateHeaders),
                    const SizedBox(height: 10),
                    _buildMappingDropdown(setDialogState, '类型列(收支)',
                        _mapping.typeCol, _typeHeaders),
                    const SizedBox(height: 10),
                    _buildMappingDropdown(setDialogState, '金额列',
                        _mapping.amountCol, _amountHeaders),
                    const SizedBox(height: 10),
                    _buildMappingDropdown(setDialogState, '分类列',
                        _mapping.categoryCol, _categoryHeaders),
                    const SizedBox(height: 10),
                    _buildMappingDropdown(setDialogState, '备注列',
                        _mapping.noteCol, _noteHeaders),
                    const SizedBox(height: 10),
                    _buildMappingDropdown(setDialogState, '账户列',
                        _mapping.accountCol, _accountHeaders),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() => _buildPreview());
                },
                child: const Text('应用'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMappingDropdown(StateSetter setDialogState, String label,
      int? currentValue, List<String> autoMatchHeaders) {
    final items = <DropdownMenuItem<int?>>[
      const DropdownMenuItem(value: null, child: Text('-- 不映射 --')),
    ];
    for (var i = 0; i < widget.headers.length; i++) {
      final h = widget.headers[i];
      final isMatched =
          autoMatchHeaders.any((p) => h.contains(p) || p.contains(h));
      final marker = isMatched ? ' [匹配]' : '';
      items.add(DropdownMenuItem(value: i, child: Text('列$i: $h$marker')));
    }
    return Row(
      children: [
        SizedBox(width: 60, child: Text(label, style: const TextStyle(fontSize: 13))),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButton<int?>(
            value: currentValue,
            isExpanded: true,
            items: items,
            onChanged: (v) {
              setDialogState(() {
                switch (label) {
                  case '日期列':
                    _mapping.dateCol = v;
                  case '类型列(收支)':
                    _mapping.typeCol = v;
                  case '金额列':
                    _mapping.amountCol = v;
                  case '分类列':
                    _mapping.categoryCol = v;
                  case '备注列':
                    _mapping.noteCol = v;
                  case '账户列':
                    _mapping.accountCol = v;
                }
              });
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final validCount = _previewRows.where((r) => r.selected && r.warning == null).length;
    final warningCount = _previewRows.where((r) => r.selected && r.warning != null).length;
    final mappedOk = _mapping.isValid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('导入预览'),
        actions: [
          if (!_importing)
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: '调整列映射',
              onPressed: _showMappingDialog,
            ),
        ],
      ),
      body: Column(
        children: [
          // Summary card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: colorScheme.surfaceContainerLow,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.fileName,
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildStatChip(
                        '共 ${widget.rows.length} 条', null, colorScheme),
                    const SizedBox(width: 8),
                    _buildStatChip(
                        '可导入 $validCount 条', Colors.green, colorScheme),
                    if (warningCount > 0) ...[
                      const SizedBox(width: 8),
                      _buildStatChip(
                          '$warningCount 条异常', Colors.orange, colorScheme),
                    ],
                    const Spacer(),
                    if (widget.template != null)
                      Chip(
                        avatar: Icon(Icons.check_circle,
                            size: 16, color: colorScheme.primary),
                        label: Text(
                            widget.template == 'wechat' ? '微信账单' : '支付宝账单',
                            style: const TextStyle(fontSize: 11)),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                if (!mappedOk) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 16, color: colorScheme.error),
                      const SizedBox(width: 4),
                      Text('缺少日期或金额列映射，请点击右上角调整',
                          style: TextStyle(
                              fontSize: 12, color: colorScheme.error)),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Select all / deselect all
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Checkbox(
                  value: _selectAll,
                  tristate: !_selectAll &&
                      _previewRows.any((r) => r.selected),
                  onChanged: (v) {
                    setState(() {
                      _selectAll = v ?? false;
                      for (final r in _previewRows) {
                        r.selected = _selectAll;
                      }
                    });
                  },
                ),
                Text(
                    '${_previewRows.where((r) => r.selected).length}/${_previewRows.length} 已选',
                    style: Theme.of(context).textTheme.bodySmall),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() {
                      for (final r in _previewRows) {
                        r.selected = r.warning == null;
                      }
                      _selectAll =
                          _previewRows.every((r) => r.selected);
                    });
                  },
                  child: const Text('只选有效', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),

          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              border: Border(
                  top: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
                  bottom:
                      BorderSide(color: colorScheme.outlineVariant, width: 0.5)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 40),
                Expanded(
                    flex: 3,
                    child: Text('日期/类型/金额',
                        style: _headerStyle(colorScheme))),
                Expanded(
                    flex: 2,
                    child: Text('分类/备注',
                        style: _headerStyle(colorScheme))),
                const SizedBox(width: 8),
              ],
            ),
          ),

          // Table body
          Expanded(
            child: ListView.builder(
              itemCount: _previewRows.length,
              itemBuilder: (context, index) {
                final row = _previewRows[index];
                final hasWarning = row.warning != null;
                final bgColor = row.selected
                    ? (hasWarning ? Colors.orange.withAlpha(20) : null)
                    : colorScheme.surfaceContainerLow;

                return Container(
                  color: bgColor,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Checkbox(
                        value: row.selected,
                        visualDensity: VisualDensity.compact,
                        onChanged: (v) {
                          setState(() {
                            row.selected = v ?? false;
                            _selectAll =
                                _previewRows.every((r) => r.selected);
                          });
                        },
                      ),
                      // Date / Type / Amount
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(row.date ?? '-',
                                style: const TextStyle(fontSize: 13)),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                if (row.matchedType != null)
                                  Container(
                                    margin: const EdgeInsets.only(
                                        right: 4),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 3, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: colorScheme
                                          .primaryContainer,
                                      borderRadius:
                                          BorderRadius.circular(2),
                                    ),
                                    child: Text(
                                      row.matchedType == 0
                                          ? '支出'
                                          : '收入',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: colorScheme
                                            .onPrimaryContainer,
                                      ),
                                    ),
                                  ),
                                Text(
                                    row.amountStr ?? '-',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: row.typeStr == '收入'
                                          ? colorScheme.tertiary
                                          : colorScheme.error,
                                    )),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Category / Note
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            if (row.matchedCategory != null)
                              Text(row.matchedCategory!,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: colorScheme.primary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            if (row.noteStr != null)
                              Text(row.noteStr!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color:
                                        colorScheme.onSurface
                                            .withAlpha(179),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      // Warning icon
                      if (hasWarning)
                        Tooltip(
                          message: row.warning!,
                          child: Icon(Icons.warning_amber_rounded,
                              size: 16, color: Colors.orange.shade700),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _importing || !mappedOk || validCount == 0
                ? null
                : _doImport,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
            child: _importing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text('导入 $validCount 条记录'),
          ),
        ),
      ),
    );
  }

  TextStyle _headerStyle(ColorScheme cs) =>
      TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.outline);

  Widget _buildStatChip(String label, Color? color, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color != null ? color.withAlpha(25) : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: color != null
                ? color.withAlpha(80)
                : cs.outlineVariant),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 12, color: color ?? cs.onSurface, fontWeight: FontWeight.w500)),
    );
  }
}
