import 'package:flutter/material.dart';

/// 表格列定义。
class TableColumnSpec {
  const TableColumnSpec(this.label, {this.flex = 1, this.numeric = false});

  final String label;
  final int flex;

  /// 数值列右对齐。
  final bool numeric;
}

/// 密集表格卡(模型用量、分组分布等)。用 [TableColumnSpec] 描述表头,
/// [rows] 每行为与列等长的单元格 Widget 列表(数值列自动右对齐)。
class DataTableCard extends StatelessWidget {
  const DataTableCard({
    super.key,
    required this.columns,
    required this.rows,
    this.emptyHint,
  });

  final List<TableColumnSpec> columns;
  final List<List<Widget>> rows;
  final String? emptyHint;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              emptyHint ?? '',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ),
      );
    }

    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(
              children: [
                for (final col in columns)
                  Expanded(
                    flex: col.flex,
                    child: Text(
                      col.label,
                      textAlign: col.numeric ? TextAlign.right : TextAlign.left,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          for (var r = 0; r < rows.length; r++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  for (var c = 0; c < columns.length; c++)
                    Expanded(
                      flex: columns[c].flex,
                      child: Align(
                        alignment: columns[c].numeric
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: rows[r][c],
                      ),
                    ),
                ],
              ),
            ),
            if (r != rows.length - 1)
              Divider(
                height: 1,
                color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
              ),
          ],
        ],
      ),
    );
  }
}
