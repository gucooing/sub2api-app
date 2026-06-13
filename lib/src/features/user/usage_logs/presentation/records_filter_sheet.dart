import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../i18n/app_localizations.dart';
import '../../../../shared/format/formatters.dart';
import '../../keys/providers/keys_providers.dart';
import '../providers/usage_logs_providers.dart';

/// 打开使用记录多维筛选弹层。应用后调用 [UsageRecordsNotifier.applyFilter]。
Future<void> showRecordsFilterSheet(BuildContext context, WidgetRef ref) {
  final current = ref.read(usageRecordsProvider).filter;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _FilterSheet(initial: current),
  );
}

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet({required this.initial});

  final UsageLogFilter initial;

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  int? _apiKeyId;
  int? _groupId;
  bool? _stream;
  String? _startDate;
  String? _endDate;
  late final TextEditingController _model;

  @override
  void initState() {
    super.initState();
    _apiKeyId = widget.initial.apiKeyId;
    _groupId = widget.initial.groupId;
    _stream = widget.initial.stream;
    _startDate = widget.initial.startDate;
    _endDate = widget.initial.endDate;
    _model = TextEditingController(text: widget.initial.model ?? '');
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  void _apply() {
    final filter = UsageLogFilter(
      apiKeyId: _apiKeyId,
      groupId: _groupId,
      model: _model.text.trim().isEmpty ? null : _model.text.trim(),
      stream: _stream,
      startDate: _startDate,
      endDate: _endDate,
    );
    ref.read(usageRecordsProvider.notifier).applyFilter(filter);
    Navigator.of(context).pop();
  }

  void _reset() {
    ref.read(usageRecordsProvider.notifier).applyFilter(const UsageLogFilter());
    Navigator.of(context).pop();
  }

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _startDate = formatDate(picked.start);
        _endDate = formatDate(picked.end);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final keys = ref.watch(keysListProvider).value ?? const [];
    final groups = ref.watch(availableGroupsProvider).value ?? const [];

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.tr('usage.filter'),
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            // 密钥
            DropdownButtonFormField<int?>(
              initialValue: _apiKeyId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: context.tr('nav.keys'),
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(value: null, child: Text(context.tr('usage.allKeys'))),
                for (final k in keys)
                  DropdownMenuItem(
                      value: k.id,
                      child: Text(k.name, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() => _apiKeyId = v),
            ),
            const SizedBox(height: 14),
            // 分组
            DropdownButtonFormField<int?>(
              initialValue: _groupId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: context.tr('keys.group'),
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                    value: null, child: Text(context.tr('usage.allGroups'))),
                for (final g in groups)
                  DropdownMenuItem(
                      value: g.id,
                      child: Text(g.name, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() => _groupId = v),
            ),
            const SizedBox(height: 14),
            // 模型
            TextFormField(
              controller: _model,
              decoration: InputDecoration(
                labelText: context.tr('usage.model'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            // 流式
            Align(
              alignment: Alignment.centerLeft,
              child: Text(context.tr('usage.stream'),
                  style: Theme.of(context).textTheme.bodyMedium),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text(context.tr('usage.streamAll')),
                  selected: _stream == null,
                  onSelected: (_) => setState(() => _stream = null),
                ),
                ChoiceChip(
                  label: Text(context.tr('usage.streamYes')),
                  selected: _stream == true,
                  onSelected: (_) => setState(() => _stream = true),
                ),
                ChoiceChip(
                  label: Text(context.tr('usage.streamNo')),
                  selected: _stream == false,
                  onSelected: (_) => setState(() => _stream = false),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // 日期范围
            OutlinedButton.icon(
              onPressed: _pickDates,
              icon: const Icon(Icons.date_range),
              label: Text(
                _startDate != null
                    ? '$_startDate ~ $_endDate'
                    : context.tr('usage.customRange'),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _reset,
                    child: Text(context.tr('usage.reset')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _apply,
                    child: Text(context.tr('usage.apply')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
