import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../i18n/app_localizations.dart';
import '../format/formatters.dart';
import 'multi_series_trend_chart.dart';

/// 构造「token 趋势多线图」的标准 6 条系列(总览与用量页共用,确保两处一致):
/// 输入 / 输出 / 缓存创建 / 缓存读取 四条 token 实线 + 缓存命中率(%)+ 金额($)
/// 两条虚线。各参数为与 X 轴等长的真实值序列。
List<TrendSeries> tokenTrendSeries(
  BuildContext context, {
  required List<double> input,
  required List<double> output,
  required List<double> cacheCreation,
  required List<double> cacheRead,
  required List<double> cacheHitRate,
  required List<double> amount,
}) {
  String compact(double v) => formatCompact(v.round());
  return [
    TrendSeries(
      key: 'input',
      label: context.tr('tokens.input'),
      color: AppColors.brandBlue,
      values: input,
      format: compact,
    ),
    TrendSeries(
      key: 'output',
      label: context.tr('tokens.output'),
      color: AppColors.brandGreen,
      values: output,
      format: compact,
    ),
    TrendSeries(
      key: 'cacheCreation',
      label: context.tr('tokens.cacheCreation'),
      color: const Color(0xFFF59E0B),
      values: cacheCreation,
      format: compact,
    ),
    TrendSeries(
      key: 'cacheRead',
      label: context.tr('tokens.cacheRead'),
      color: const Color(0xFF06B6D4),
      values: cacheRead,
      format: compact,
    ),
    TrendSeries(
      key: 'cacheHitRate',
      label: context.tr('tokens.cacheHitRate'),
      color: const Color(0xFF8B5CF6),
      dashed: true,
      values: cacheHitRate,
      format: (v) => '${v.toStringAsFixed(1)}%',
    ),
    TrendSeries(
      key: 'amount',
      label: context.tr('tokens.amount'),
      color: Theme.of(context).colorScheme.primary,
      dashed: true,
      values: amount,
      format: formatCost,
    ),
  ];
}
