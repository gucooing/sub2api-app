import 'package:flutter/material.dart';

import '../../../../core/session/auth_models.dart';

/// 一个「可选开启的功能」描述:由管理员在后端 `/settings/public` 的开关决定是否展示。
///
/// 完整页面(充值/邀请返利/可用渠道/渠道状态)对应方案中的 P5–P7,
/// 当前先以占位页接入;开关关闭时入口完全不出现。
@immutable
class UserFeature {
  const UserFeature({
    required this.id,
    required this.icon,
    required this.labelKey,
    required this.route,
    required this.isEnabled,
  });

  final String id;
  final IconData icon;

  /// i18n 键。
  final String labelKey;

  /// 跳转路由(当前为占位页,后续替换为真实页面)。
  final String route;

  /// 从公开设置判断该功能是否被管理员开启。
  final bool Function(PublicSettingsLite settings) isEnabled;
}

/// 全部可开关功能(顺序即展示顺序)。
const List<UserFeature> kUserFeatures = [
  UserFeature(
    id: 'recharge',
    icon: Icons.account_balance_wallet_outlined,
    labelKey: 'features.recharge',
    route: '/recharge',
    isEnabled: _paymentEnabled,
  ),
  UserFeature(
    id: 'affiliate',
    icon: Icons.handshake_outlined,
    labelKey: 'features.affiliate',
    route: '/affiliate',
    isEnabled: _affiliateEnabled,
  ),
  UserFeature(
    id: 'availableChannels',
    icon: Icons.hub_outlined,
    labelKey: 'features.availableChannels',
    route: '/channels',
    isEnabled: _availableChannelsEnabled,
  ),
  UserFeature(
    id: 'channelStatus',
    icon: Icons.monitor_heart_outlined,
    labelKey: 'features.channelStatus',
    route: '/channel-status',
    isEnabled: _channelMonitorEnabled,
  ),
];

bool _paymentEnabled(PublicSettingsLite s) => s.paymentEnabled;
bool _affiliateEnabled(PublicSettingsLite s) => s.affiliateEnabled;
bool _availableChannelsEnabled(PublicSettingsLite s) =>
    s.availableChannelsEnabled;
bool _channelMonitorEnabled(PublicSettingsLite s) => s.channelMonitorEnabled;

/// 当前管理员已开启、应展示给用户的功能入口。
List<UserFeature> enabledUserFeatures(PublicSettingsLite settings) =>
    kUserFeatures.where((f) => f.isEnabled(settings)).toList(growable: false);

/// 当前角色可见的自定义页面(普通用户只看 visibility=user,管理员额外看 admin),
/// 已按 sort_order 升序排序。
List<CustomMenuItem> visibleCustomPages(
  PublicSettingsLite settings, {
  required bool isAdmin,
}) {
  final items = settings.customMenuItems.where((item) {
    if (item.visibility == 'admin') return isAdmin;
    return item.visibility == 'user';
  }).toList();
  items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  return items;
}
