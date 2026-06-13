import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// 用量/配额进度条(纯进度,无文案,便于组合)。
///
/// [max] 为空或 <=0 视为“不限”,只画空轨道(由调用方负责文案)。
/// 颜色随占比变化:<70% 品牌色,<90% 警告,>=90% 危险。
class ProgressMeter extends StatelessWidget {
  const ProgressMeter({
    super.key,
    required this.value,
    required this.max,
    this.height = 6,
    this.color,
  });

  final double value;
  final double? max;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasLimit = max != null && max! > 0;
    final ratio = hasLimit ? (value / max!).clamp(0.0, 1.0) : 0.0;
    final barColor = color ??
        (ratio >= 0.9
            ? scheme.error
            : ratio >= 0.7
                ? const Color(0xFFB7791F)
                : AppColors.brandBlue);

    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: hasLimit ? ratio : 0,
        minHeight: height,
        backgroundColor: scheme.surfaceContainerHighest,
        valueColor: AlwaysStoppedAnimation(barColor),
      ),
    );
  }
}
