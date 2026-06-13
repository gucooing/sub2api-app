import 'package:flutter/material.dart';

import 'delta_badge.dart';
import 'sparkline.dart';

/// Pro 控制台核心磁贴:标签 + 大数值 + 涨跌幅 + 内联迷你折线。
///
/// 在网格中铺开(建议 childAspectRatio ≈ 1.5)。[spark] 为空时不画折线,
/// [deltaPercent] 为空时不画涨跌徽标。
class KpiTile extends StatelessWidget {
  const KpiTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.deltaPercent,
    this.spark,
    this.accent,
    this.invertDelta = false,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData? icon;
  final double? deltaPercent;
  final List<double>? spark;
  final Color? accent;
  final bool invertDelta;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accentColor = accent ?? scheme.primary;

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 15, color: accentColor),
                    const SizedBox(width: 5),
                  ],
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ),
                  if (deltaPercent != null) ...[
                    const SizedBox(width: 6),
                    DeltaBadge(percent: deltaPercent, invert: invertDelta),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 22,
                width: double.infinity,
                child: (spark != null && spark!.length >= 2)
                    ? Sparkline(values: spark!, color: accentColor)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
