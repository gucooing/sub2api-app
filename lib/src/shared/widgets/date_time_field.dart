import 'package:flutter/material.dart';

import '../format/formatters.dart';

/// 统一的「日期时间」选择字段:点按弹出日期+时间选择器,可清除。
/// 供公告、优惠码、订阅等需要 datetime-local 的表单复用。
class DateTimeField extends StatelessWidget {
  const DateTimeField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.emptyHint,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final String? emptyHint;

  Future<void> _pick(BuildContext context) async {
    final base = value ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (!context.mounted) return;
    final t = time ?? TimeOfDay.fromDateTime(base);
    onChanged(
        DateTime(date.year, date.month, date.day, t.hour, t.minute));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => _pick(context),
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: value != null
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => onChanged(null),
                )
              : const Icon(Icons.event, size: 18),
        ),
        child: Text(
          value == null ? (emptyHint ?? '') : formatDateTime(value!),
          style:
              value == null ? TextStyle(color: scheme.onSurfaceVariant) : null,
        ),
      ),
    );
  }
}
