import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 多线趋势图的一条数据系列(与 API DTO 解耦)。
class TrendSeries {
  const TrendSeries({
    required this.key,
    required this.label,
    required this.color,
    required this.values,
    required this.format,
    this.dashed = false,
    this.initiallyVisible = true,
  });

  /// 稳定标识(可见性集合用它),如 `input` / `cacheHitRate`。
  final String key;

  /// 图例显示名。
  final String label;
  final Color color;

  /// 与 X 轴一一对应的原始真实值(token 数 / 百分比 / 金额等)。
  final List<double> values;

  /// 真实值 → 展示文案(图例最新值与触摸提示共用)。
  final String Function(double value) format;

  /// 副量纲线(命中率 / 金额)画虚线以区分。
  final bool dashed;
  final bool initiallyVisible;
}

/// 多系列折线趋势图:把量纲差异巨大的多条线(token 数 / 命中率% / 金额$)
/// 按各自峰值独立归一化到同一高度,叠放在一张图里,任意线都清晰可见。
///
/// 左轴不显示绝对刻度(混用量纲会误导),真实数值改由图例 chip(该线最新值)
/// 与触摸提示(各线精确值)承载;点按图例可快捷切换显示哪些线。
class MultiSeriesTrendChart extends StatefulWidget {
  const MultiSeriesTrendChart({
    super.key,
    required this.labels,
    required this.series,
    this.emptyHint,
  });

  /// X 轴短标签(如 06-13 或 08:00),长度应与各 series.values 一致。
  final List<String> labels;
  final List<TrendSeries> series;
  final String? emptyHint;

  @override
  State<MultiSeriesTrendChart> createState() => _MultiSeriesTrendChartState();
}

class _MultiSeriesTrendChartState extends State<MultiSeriesTrendChart> {
  late Set<String> _visible;

  @override
  void initState() {
    super.initState();
    _resetVisible();
  }

  @override
  void didUpdateWidget(MultiSeriesTrendChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    // series 集合变化(如刷新得到新维度)时,补齐新键的默认可见性。
    final oldKeys = oldWidget.series.map((s) => s.key).toSet();
    final newKeys = widget.series.map((s) => s.key).toSet();
    if (!setEquals(oldKeys, newKeys)) {
      _resetVisible();
    }
  }

  void _resetVisible() {
    _visible = {
      for (final s in widget.series)
        if (s.initiallyVisible) s.key,
    };
  }

  double _maxOf(TrendSeries s) =>
      s.values.fold<double>(0, (a, b) => b > a ? b : a);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (widget.labels.isEmpty || widget.series.isEmpty) {
      return Center(
        child: Text(
          widget.emptyHint ?? '',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      );
    }

    final n = widget.labels.length;
    final visibleSeries =
        widget.series.where((s) => _visible.contains(s.key)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: 1,
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
                // 左右各预留一点空白,让 x 轴首尾标签不被图表边缘裁切。
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 16),
                ),
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 16),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: (n / 4).ceilToDouble().clamp(1, 366),
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= n) return const SizedBox.shrink();
                      return SideTitleWidget(
                        meta: meta,
                        space: 4,
                        child: Text(
                          widget.labels[i],
                          style: theme.textTheme.labelSmall,
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  maxContentWidth: 220,
                  // 提示框始终夹在图表内,避免数据值大或点在边缘时溢出被裁切。
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItems: (touched) {
                    // 同一竖线上每条线一项;首项前置日期标签。
                    return [
                      for (var k = 0; k < touched.length; k++)
                        () {
                          final spot = touched[k];
                          final s = visibleSeries[spot.barIndex];
                          final i = spot.x.toInt();
                          final real =
                              (i >= 0 && i < s.values.length) ? s.values[i] : 0;
                          final prefix =
                              k == 0 ? '${widget.labels[i]}\n' : '';
                          return LineTooltipItem(
                            '$prefix${s.label}: ${s.format(real.toDouble())}',
                            TextStyle(
                              color: s.color,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        }(),
                    ];
                  },
                ),
              ),
              lineBarsData: [
                for (final s in visibleSeries) _barData(s),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        _Legend(
          series: widget.series,
          visible: _visible,
          maxLabel: (s) =>
              s.values.isEmpty ? '' : s.format(s.values.last),
          onToggle: (key) => setState(() {
            if (_visible.contains(key)) {
              _visible.remove(key);
            } else {
              _visible.add(key);
            }
          }),
        ),
      ],
    );
  }

  /// 把一条 series 按自身峰值归一化到 0..1 的折线。
  LineChartBarData _barData(TrendSeries s) {
    final max = _maxOf(s);
    final spots = [
      for (var i = 0; i < s.values.length; i++)
        FlSpot(i.toDouble(), max <= 0 ? 0 : (s.values[i] / max).clamp(0, 1)),
    ];
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.25,
      color: s.color,
      barWidth: 2.4,
      dashArray: s.dashed ? const [5, 5] : null,
      dotData: FlDotData(show: s.values.length <= 14),
      belowBarData: BarAreaData(
        // 仅实线(token)填充淡色;虚线副量纲线不填充,避免叠加糊成一片。
        show: !s.dashed,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            s.color.withValues(alpha: 0.14),
            s.color.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}

/// 可点按图例:色点(虚线线型画成虚线)+ 名称 + 最新真实值;点按切换显隐。
class _Legend extends StatelessWidget {
  const _Legend({
    required this.series,
    required this.visible,
    required this.maxLabel,
    required this.onToggle,
  });

  final List<TrendSeries> series;
  final Set<String> visible;
  final String Function(TrendSeries) maxLabel;
  final void Function(String key) onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        for (final s in series)
          () {
            final on = visible.contains(s.key);
            final color = on
                ? s.color
                : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5);
            return InkWell(
              onTap: () => onToggle(s.key),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Swatch(color: color, dashed: s.dashed),
                    const SizedBox(width: 6),
                    Text(
                      s.label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: on
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurfaceVariant,
                        decoration: on ? null : TextDecoration.lineThrough,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      maxLabel(s),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }(),
      ],
    );
  }
}

/// 图例色块:实线画实心条,虚线画断点条以对应图中线型。
class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.dashed});

  final Color color;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    if (!dashed) {
      return Container(
        width: 14,
        height: 3,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      );
    }
    return SizedBox(
      width: 14,
      height: 3,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var i = 0; i < 3; i++)
            Container(width: 3, height: 3, color: color),
        ],
      ),
    );
  }
}
