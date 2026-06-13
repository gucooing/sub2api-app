import 'package:flutter/material.dart';

import '../../../../shared/widgets/status_pill.dart';

/// 公告 type → 语义色调,跨列表/详情统一。
StatusTone announcementTone(String type) {
  switch (type) {
    case 'warning':
      return StatusTone.warning;
    case 'error':
      return StatusTone.danger;
    case 'success':
      return StatusTone.positive;
    default:
      return StatusTone.info;
  }
}

/// 公告 type → 图标。
IconData announcementIcon(String type) {
  switch (type) {
    case 'warning':
      return Icons.warning_amber_rounded;
    case 'error':
      return Icons.error_outline;
    case 'success':
      return Icons.check_circle_outline;
    default:
      return Icons.campaign_outlined;
  }
}

/// 公告 type → i18n 标签键。
String announcementTypeLabelKey(String type) {
  switch (type) {
    case 'warning':
      return 'announcements.typeWarning';
    case 'error':
      return 'announcements.typeError';
    case 'success':
      return 'announcements.typeSuccess';
    default:
      return 'announcements.typeInfo';
  }
}
