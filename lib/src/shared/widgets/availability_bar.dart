import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// 可用率条:横向进度 + 百分比文案,按健康度上色。
/// 适用于渠道状态页(7/15/30 天可用率)。
class AvailabilityBar extends StatelessWidget {
  const AvailabilityBar({
    super.key,
    required this.percent,
    this.label,
    this.height = 6,
  });

  /// 0–100。
  final double percent;
  final String? label;
  final double height;

  Color _color() {
    if (percent >= 99) return AppColors.brandGreen;
    if (percent >= 95) return AppColors.brandBlue;
    if (percent >= 80) return const Color(0xFFB7791F);
    return const Color(0xFFDC2626);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = _color();
    return Row(
      children: [
        if (label != null) ...[
          SizedBox(
            width: 34,
            child: Text(
              label!,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(height),
            child: LinearProgressIndicator(
              value: (percent / 100).clamp(0.0, 1.0),
              minHeight: height,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${percent.toStringAsFixed(percent >= 99.95 ? 0 : 1)}%',
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
