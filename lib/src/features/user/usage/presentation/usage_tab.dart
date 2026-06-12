import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../i18n/app_localizations.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../data/usage_api.dart';
import '../providers/usage_providers.dart';

/// 「用量」tab:时间范围切换 + 消耗趋势图 + 按模型统计表。
class UsageTab extends ConsumerWidget {
  const UsageTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(usageRangeProvider);
    final trend = ref.watch(usageTrendProvider);
    final models = ref.watch(usageModelsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('nav.usage'))),
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
            Center(
              child: SegmentedButton<UsageRange>(
                segments: [
                  ButtonSegment(
                    value: UsageRange.today,
                    label: Text(context.tr('usage.today')),
                  ),
                  ButtonSegment(
                    value: UsageRange.week,
                    label: Text(context.tr('usage.week')),
                  ),
                  ButtonSegment(
                    value: UsageRange.month,
                    label: Text(context.tr('usage.month')),
                  ),
                ],
                selected: {range},
                onSelectionChanged: (sel) =>
                    ref.read(usageRangeProvider.notifier).set(sel.first),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('usage.costTrend'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                child: SizedBox(
                  height: 220,
                  child: AsyncValueView(
                    value: trend,
                    onRetry: () => ref.invalidate(usageTrendProvider),
                    builder: (context, points) => _TrendChart(points: points),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('usage.byModel'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            AsyncValueView(
              value: models,
              onRetry: () => ref.invalidate(usageModelsProvider),
              builder: (context, list) => _ModelTable(stats: list),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.points});

  final List<TrendPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return Center(child: Text(context.tr('common.empty')));
    }
    final scheme = Theme.of(context).colorScheme;
    final spots = [
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].actualCost),
    ];
    final maxY =
        spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY <= 0 ? 1 : maxY * 1.2,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (value, meta) => Text(
                value >= 1
                    ? value.toStringAsFixed(1)
                    : value.toStringAsFixed(2),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (points.length / 4).ceilToDouble().clamp(1, 31),
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= points.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _shortLabel(points[i].date),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touched) => [
              for (final spot in touched)
                LineTooltipItem(
                  '${_shortLabel(points[spot.x.toInt()].date)}\n\$${spot.y.toStringAsFixed(4)}',
                  TextStyle(color: scheme.onInverseSurface),
                ),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.25,
            color: scheme.primary,
            barWidth: 2.5,
            dotData: FlDotData(show: points.length <= 14),
            belowBarData: BarAreaData(
              show: true,
              color: scheme.primary.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
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

class _ModelTable extends StatelessWidget {
  const _ModelTable({required this.stats});

  final List<ModelUsageStat> stats;

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(child: Text(context.tr('common.empty'))),
        ),
      );
    }
    final sorted = [...stats]
      ..sort((a, b) => b.actualCost.compareTo(a.actualCost));

    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    context.tr('usage.model'),
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                Expanded(
                  child: Text(
                    context.tr('dashboard.requests'),
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    context.tr('dashboard.cost'),
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 8),
          for (final stat in sorted)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      stat.model,
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${stat.requests}',
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '\$${stat.actualCost.toStringAsFixed(4)}',
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
