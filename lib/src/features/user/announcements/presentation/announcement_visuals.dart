import 'package:flutter/material.dart';

import '../../../../shared/widgets/status_pill.dart';

/// 公告 notify_mode → 语义色调(popup 更醒目,silent 中性)。
StatusTone announcementTone(String notifyMode) =>
    notifyMode == 'popup' ? StatusTone.info : StatusTone.neutral;

/// 公告 notify_mode → 图标。
IconData announcementIcon(String notifyMode) =>
    notifyMode == 'popup' ? Icons.campaign_outlined : Icons.notifications_outlined;

/// 公告 notify_mode → i18n 标签键。
String announcementModeLabelKey(String notifyMode) =>
    notifyMode == 'popup' ? 'announcements.modePopup' : 'announcements.modeNotice';
