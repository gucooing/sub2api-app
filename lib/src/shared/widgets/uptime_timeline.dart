import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// 监控点健康度色调(渠道状态时间轴/状态点共用)。
enum MonitorTone { up, degraded, down, unknown }

Color monitorToneColor(MonitorTone tone) => switch (tone) {
      MonitorTone.up => AppColors.brandGreen,
      MonitorTone.degraded => const Color(0xFFB7791F),
      MonitorTone.down => const Color(0xFFDC2626),
      MonitorTone.unknown => const Color(0xFF94A3B8),
    };

/// 状态页式「正常运行时间」时间轴:一排细条,颜色表示各时间点的状态。
/// 最新的点在右侧。
class UptimeTimeline extends StatelessWidget {
  const UptimeTimeline({
    super.key,
    required this.ticks,
    this.height = 26,
    this.spacing = 2,
  });

  final List<MonitorTone> ticks;
  final double height;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (ticks.isEmpty) {
      return SizedBox(height: height);
    }
    return SizedBox(
      height: height,
      child: Row(
        children: [
          for (var i = 0; i < ticks.length; i++) ...[
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: monitorToneColor(ticks[i]),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            if (i != ticks.length - 1) SizedBox(width: spacing),
          ],
        ],
      ),
    );
  }
}

/// 单个状态圆点(配合标签使用)。
class MonitorDot extends StatelessWidget {
  const MonitorDot({super.key, required this.tone, this.size = 8});

  final MonitorTone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: monitorToneColor(tone),
        shape: BoxShape.circle,
      ),
    );
  }
}
