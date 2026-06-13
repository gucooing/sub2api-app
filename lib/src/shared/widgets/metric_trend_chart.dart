import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// 趋势图的中性数据点(与 API DTO 解耦)。
class TrendChartPoint {
  const TrendChartPoint({required this.label, required this.value});

  /// X 轴短标签(如 06-13 或 08:00)。
  final String label;

  /// Y 值(金额或 token 数等)。
  final double value;
}

/// 通用折线趋势图(品牌渐变填充 + 触摸提示),供总览/用量/密钥详情复用。
///
/// 泛化自原 usage_tab 的内部 `_TrendChart`,改为接受中性数据点 + 可注入
/// 数值格式化,从而同一组件既能画「消耗($)」也能画「Tokens」。
class MetricTrendChart extends StatelessWidget {
  const MetricTrendChart({
    super.key,
    required this.points,
    required this.valueLabel,
    this.color,
    this.emptyHint,
  });

  final List<TrendChartPoint> points;

  /// Y 值 → 展示文案(轴标签与提示框共用)。
  final String Function(double value) valueLabel;
  final Color? color;
  final String? emptyHint;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return Center(
        child: Text(
          emptyHint ?? '',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final lineColor = color ?? scheme.primary;
    final spots = [
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].value),
    ];
    final maxY = spots.map((s) => s.y).fold<double>(0, (a, b) => a > b ? a : b);

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
          // 右侧预留少量空白,避免 x 轴最后一个标签被边缘裁切(左侧已有 y 轴占位)。
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 16),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 46,
              getTitlesWidget: (value, meta) {
                if (value == meta.max) return const SizedBox.shrink();
                return Text(
                  valueLabel(value),
                  style: Theme.of(context).textTheme.labelSmall,
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (points.length / 4).ceilToDouble().clamp(1, 366),
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= points.length) return const SizedBox.shrink();
                return SideTitleWidget(
                  meta: meta,
                  space: 4,
                  child: Text(
                    points[i].label,
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
            // 提示框夹在图表内,避免数据值大或点在边缘时溢出被裁切。
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (touched) => [
              for (final spot in touched)
                LineTooltipItem(
                  '${points[spot.x.toInt()].label}\n${valueLabel(spot.y)}',
                  TextStyle(color: scheme.onInverseSurface, fontSize: 12),
                ),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.25,
            color: lineColor,
            barWidth: 2.5,
            dotData: FlDotData(show: points.length <= 14),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  lineColor.withValues(alpha: 0.22),
                  lineColor.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
