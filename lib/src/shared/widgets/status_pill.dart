import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// 状态语义色调,跨密钥/账号/渠道/订单统一。
enum StatusTone { positive, neutral, warning, danger, info }

/// 统一的状态胶囊。各业务把自己的状态字符串映射到 [StatusTone] 后复用本组件,
/// 保证全局状态配色一致。
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    this.tone = StatusTone.neutral,
    this.dense = false,
  });

  final String label;
  final StatusTone tone;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (fg, bg) = switch (tone) {
      StatusTone.positive => (
          AppColors.brandGreen,
          AppColors.brandGreen.withValues(alpha: 0.14)
        ),
      StatusTone.info => (scheme.primary, scheme.primary.withValues(alpha: 0.12)),
      StatusTone.warning => (
          const Color(0xFFB7791F),
          const Color(0xFFB7791F).withValues(alpha: 0.14)
        ),
      StatusTone.danger => (scheme.error, scheme.error.withValues(alpha: 0.12)),
      StatusTone.neutral => (
          scheme.onSurfaceVariant,
          scheme.surfaceContainerHighest
        ),
    };

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: dense ? 6 : 8, vertical: dense ? 2 : 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 5),
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: fg, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
