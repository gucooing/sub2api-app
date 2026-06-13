import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// 涨跌幅徽标:▲12.3% / ▼4.5%。[percent] 为空时不渲染(无可比基准)。
///
/// 默认上涨用品牌绿、下跌用错误红(趋势方向);对于“越低越好”的指标
/// (如错误率)可传 [invert] 反转配色。
class DeltaBadge extends StatelessWidget {
  const DeltaBadge({
    super.key,
    required this.percent,
    this.invert = false,
  });

  final double? percent;
  final bool invert;

  @override
  Widget build(BuildContext context) {
    final p = percent;
    if (p == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final up = p >= 0;
    final good = invert ? !up : up;
    final color = p.abs() < 0.05
        ? scheme.onSurfaceVariant
        : (good ? AppColors.brandGreen : scheme.error);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(up ? Icons.arrow_drop_up : Icons.arrow_drop_down,
              size: 14, color: color),
          Text(
            '${p.abs().toStringAsFixed(1)}%',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
