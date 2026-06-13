import 'package:flutter/widgets.dart';

import '../../../../i18n/app_localizations.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../../../../shared/widgets/uptime_timeline.dart';
import '../data/channels_api.dart';

/// 监控状态 → 时间轴/圆点色调。
MonitorTone monitorTone(MonitorStatus s) => switch (s) {
      MonitorStatus.operational => MonitorTone.up,
      MonitorStatus.degraded => MonitorTone.degraded,
      MonitorStatus.failed => MonitorTone.down,
      MonitorStatus.unknown => MonitorTone.unknown,
    };

/// 监控状态 → 胶囊语义色。
StatusTone monitorStatusTone(MonitorStatus s) => switch (s) {
      MonitorStatus.operational => StatusTone.positive,
      MonitorStatus.degraded => StatusTone.warning,
      MonitorStatus.failed => StatusTone.danger,
      MonitorStatus.unknown => StatusTone.neutral,
    };

/// 监控状态 → 本地化标签。
String monitorStatusLabel(BuildContext context, MonitorStatus s) {
  switch (s) {
    case MonitorStatus.operational:
      return context.tr('channels.statusOperational');
    case MonitorStatus.degraded:
      return context.tr('channels.statusDegraded');
    case MonitorStatus.failed:
      return context.tr('channels.statusFailed');
    case MonitorStatus.unknown:
      return context.tr('channels.statusUnknown');
  }
}
