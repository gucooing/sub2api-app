import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../i18n/app_localizations.dart';
import '../../../../shared/format/formatters.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../shared/widgets/data_table_card.dart';
import '../../../../shared/widgets/multi_series_trend_chart.dart';
import '../../../../shared/widgets/responsive.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/token_trend_series.dart';
import '../data/usage_api.dart';
import '../providers/usage_providers.dart';

/// 「用量」tab:时间范围切换 + 使用记录入口 + 使用趋势(多线图,与总览一致,
/// 随本页时间筛选联动)+ 按模型统计表(请求数 / token 数 / 消费)。
class UsageTab extends ConsumerWidget {
  const UsageTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(usageDateRangeProvider);
    final trend = ref.watch(usageTrendProvider);
    final models = ref.watch(usageModelsProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(usageTrendProvider);
          ref.invalidate(usageModelsProvider);
          try {
            await ref.read(usageTrendProvider.future);
            await ref.read(usageModelsProvider.future);
          } on Exception {
            // 错误展示交给 AsyncValueView
          }
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ResponsiveCenter(
              maxWidth: 1100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DateRangeSelector(currentRange: range),
                  const SizedBox(height: 12),
                  const _RecordsEntry(),
                  const SizedBox(height: 16),
                  ResponsiveTwoPane(
                    start: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SectionHeader(title: context.tr('usage.trend')),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 16, 16, 12),
                            child: SizedBox(
                              height: 280,
                              child: AsyncValueView(
                                value: trend,
                                onRetry: () =>
                                    ref.invalidate(usageTrendProvider),
                                builder: (context, points) =>
                                    MultiSeriesTrendChart(
                                  labels: [
                                    for (final p in points) _shortLabel(p.date)
                                  ],
                                  series: _series(context, points),
                                  emptyHint: context.tr('common.empty'),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    end: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SectionHeader(title: context.tr('usage.byModel')),
                        AsyncValueView(
                          value: models,
                          onRetry: () => ref.invalidate(usageModelsProvider),
                          builder: (context, list) => _ModelTable(stats: list),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<TrendSeries> _series(BuildContext context, List<TrendPoint> points) {
    return tokenTrendSeries(
      context,
      input: [for (final p in points) p.inputTokens.toDouble()],
      output: [for (final p in points) p.outputTokens.toDouble()],
      cacheCreation: [for (final p in points) p.cacheCreationTokens.toDouble()],
      cacheRead: [for (final p in points) p.cacheReadTokens.toDouble()],
      cacheHitRate: [for (final p in points) p.cacheHitRate],
      amount: [for (final p in points) p.actualCost],
    );
  }

  /// `2026-06-13` → `06-13`;hour 粒度 `2026-06-13 08:00` → `08:00`。
  static String _shortLabel(String date) {
    if (date.contains(':')) {
      final parts = date.split(' ');
      return parts.length > 1 ? parts[1] : date;
    }
    final parts = date.split('-');
    return parts.length >= 3 ? '${parts[1]}-${parts[2]}' : date;
  }
}

/// 「使用记录」入口:进多维筛选 + 滚动加载的明细列表页。
class _RecordsEntry extends StatelessWidget {
  const _RecordsEntry();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/usage-logs'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: scheme.primary.withValues(alpha: 0.12),
                child: Icon(Icons.receipt_long_outlined,
                    size: 19, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('usageLogs.title'),
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.tr('usage.recordsHint'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// 日期范围选择器。
class _DateRangeSelector extends ConsumerWidget {
  const _DateRangeSelector({required this.currentRange});

  final DateRange currentRange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SegmentedButton<UsageRangeType>(
                segments: [
                  ButtonSegment(
                    value: UsageRangeType.today,
                    label: Text(context.tr('usage.today')),
                  ),
                  ButtonSegment(
                    value: UsageRangeType.week,
                    label: Text(context.tr('usage.week')),
                  ),
                  ButtonSegment(
                    value: UsageRangeType.month,
                    label: Text(context.tr('usage.month')),
                  ),
                ],
                selected: {currentRange.type},
                onSelectionChanged: (sel) {
                  final type = sel.first;
                  if (type != UsageRangeType.custom) {
                    ref.read(usageDateRangeProvider.notifier).setPreset(type);
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton.outlined(
              icon: const Icon(Icons.date_range),
              tooltip: context.tr('usage.customRange'),
              onPressed: () => _showDatePicker(context, ref),
            ),
          ],
        ),
        if (currentRange.type == UsageRangeType.custom) ...[
          const SizedBox(height: 8),
          Text(
            '${formatDate(currentRange.start)} - ${formatDate(currentRange.end)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ],
      ],
    );
  }

  Future<void> _showDatePicker(BuildContext context, WidgetRef ref) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: currentRange.start,
        end: currentRange.end,
      ),
    );

    if (picked != null) {
      ref.read(usageDateRangeProvider.notifier).setCustom(
            picked.start,
            picked.end,
          );
    }
  }
}

/// 按模型统计表:模型 / 请求数 / token 数 / 消费,按消费降序。
class _ModelTable extends StatelessWidget {
  const _ModelTable({required this.stats});

  final List<ModelUsageStat> stats;

  @override
  Widget build(BuildContext context) {
    final sorted = [...stats]
      ..sort((a, b) => b.actualCost.compareTo(a.actualCost));
    final theme = Theme.of(context);

    Widget cell(String text, {bool strong = false, Color? color}) => Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: strong ? FontWeight.w600 : null,
            color: color,
          ),
          overflow: TextOverflow.ellipsis,
        );

    return DataTableCard(
      emptyHint: context.tr('common.empty'),
      columns: [
        TableColumnSpec(context.tr('usage.model'), flex: 3),
        TableColumnSpec(context.tr('dashboard.requests'), flex: 2, numeric: true),
        TableColumnSpec(context.tr('dashboard.tokens'), flex: 2, numeric: true),
        TableColumnSpec(context.tr('dashboard.cost'), flex: 2, numeric: true),
      ],
      rows: [
        for (final s in sorted)
          [
            cell(s.model, strong: true),
            cell(formatInt(s.requests)),
            cell(formatCompact(s.totalTokens)),
            cell(formatCost(s.actualCost), color: theme.colorScheme.primary),
          ],
      ],
    );
  }
}
