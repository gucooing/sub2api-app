import 'package:flutter/material.dart';

import '../../../core/session/auth_models.dart';

/// 管理端「其余页面」模块清单(对照 web 管理端侧边栏)。
///
/// 底部导航已含 概览/账号池/用户/分组,故此处是除它们之外的次级模块,
/// 同时供「快捷入口」(总览)与「更多」标签复用,保持单一事实来源。
/// 未实装的模块先路由到占位页,逐步替换为真实页面。
@immutable
class AdminModule {
  const AdminModule({
    required this.icon,
    required this.labelKey,
    required this.route,
    this.isEnabled,
  });

  final IconData icon;
  final String labelKey;
  final String route;

  /// 可选的功能开关判定(对照 web featureFlag);为 null 表示恒显示。
  /// 仅在服务端开启对应功能时才展示该入口。
  final bool Function(PublicSettingsLite settings)? isEnabled;
}

const List<AdminModule> kAdminModules = [
  AdminModule(
      icon: Icons.monitor_outlined,
      labelKey: 'admin.modules.ops',
      route: '/admin/ops'),
  AdminModule(
      icon: Icons.price_change_outlined,
      labelKey: 'admin.modules.channels',
      route: '/admin/channels'),
  AdminModule(
      icon: Icons.monitor_heart_outlined,
      labelKey: 'admin.modules.channelMonitor',
      route: '/admin/monitor',
      isEnabled: _channelMonitor),
  AdminModule(
      icon: Icons.card_membership_outlined,
      labelKey: 'admin.modules.subscriptions',
      route: '/admin/subscriptions'),
  AdminModule(
      icon: Icons.campaign_outlined,
      labelKey: 'admin.modules.announcements',
      route: '/admin/announcements-admin'),
  AdminModule(
      icon: Icons.dns_outlined,
      labelKey: 'admin.modules.proxies',
      route: '/admin/proxies'),
  AdminModule(
      icon: Icons.shield_outlined,
      labelKey: 'admin.modules.riskControl',
      route: '/admin/risk-control'),
  AdminModule(
      icon: Icons.card_giftcard_outlined,
      labelKey: 'admin.modules.redeem',
      route: '/admin/redeem'),
  AdminModule(
      icon: Icons.local_offer_outlined,
      labelKey: 'admin.modules.promoCodes',
      route: '/admin/promo-codes'),
  AdminModule(
      icon: Icons.people_alt_outlined,
      labelKey: 'admin.modules.affiliates',
      route: '/admin/affiliates',
      isEnabled: _affiliate),
  AdminModule(
      icon: Icons.receipt_long_outlined,
      labelKey: 'admin.modules.orders',
      route: '/admin/orders',
      isEnabled: _payment),
  AdminModule(
      icon: Icons.insights_outlined,
      labelKey: 'admin.modules.usage',
      route: '/admin/usage'),
  AdminModule(
      icon: Icons.tune_outlined,
      labelKey: 'admin.modules.settings',
      route: '/admin/settings'),
];

bool _channelMonitor(PublicSettingsLite s) => s.channelMonitorEnabled;
bool _affiliate(PublicSettingsLite s) => s.affiliateEnabled;
bool _payment(PublicSettingsLite s) => s.paymentEnabled;

/// 按服务端功能开关过滤出应展示的模块(未加载到设置时,带开关的项暂不展示)。
List<AdminModule> visibleAdminModules(PublicSettingsLite? settings) {
  return [
    for (final m in kAdminModules)
      if (m.isEnabled == null || (settings != null && m.isEnabled!(settings)))
        m,
  ];
}

