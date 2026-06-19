import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/admin/dashboard/presentation/admin_dashboard_tab.dart';
import '../../features/admin/accounts/presentation/accounts_list_page.dart';
import '../../features/admin/accounts/presentation/accounts_detail_page.dart';
import '../../features/admin/accounts/presentation/account_edit_page.dart';
import '../../features/admin/users/presentation/users_list_page.dart';
import '../../features/admin/users/presentation/user_detail_page.dart';
import '../../features/admin/groups/presentation/groups_list_page.dart';
import '../../features/admin/groups/presentation/group_edit_page.dart';
import '../../features/admin/groups/presentation/group_rates_page.dart';
import '../../features/admin/redeem/presentation/redeem_list_page.dart';
import '../../features/admin/announcements/presentation/announcements_list_page.dart';
import '../../features/admin/announcements/presentation/announcement_edit_page.dart';
import '../../features/admin/announcements/presentation/announcement_read_status_page.dart';
import '../../features/admin/promo/presentation/promo_list_page.dart';
import '../../features/admin/promo/presentation/promo_usages_page.dart';
import '../../features/admin/usage/presentation/admin_usage_list_page.dart';
import '../../features/admin/usage/presentation/admin_usage_cleanup_page.dart';
import '../../features/admin/subscriptions/presentation/subscriptions_list_page.dart';
import '../../features/admin/proxies/data/admin_proxies_api.dart';
import '../../features/admin/proxies/presentation/proxy_list_page.dart';
import '../../features/admin/proxies/presentation/proxy_edit_page.dart';
import '../../features/admin/channels/presentation/channels_list_page.dart';
import '../../features/admin/channels/presentation/channel_edit_page.dart';
import '../../features/admin/orders/presentation/orders_page.dart';
import '../../features/admin/orders/presentation/plan_edit_page.dart';
import '../../features/admin/affiliates/presentation/affiliates_page.dart';
import '../../features/admin/riskcontrol/presentation/risk_control_page.dart';
import '../../features/admin/riskcontrol/presentation/risk_config_page.dart';
import '../../features/admin/ops/presentation/ops_page.dart';
import '../../features/admin/monitor/presentation/monitor_list_page.dart';
import '../../features/admin/monitor/presentation/monitor_detail_page.dart'
    as admin_monitor;
import '../../features/admin/shell/admin_shell.dart';
import '../../features/admin/shell/admin_more_tab.dart';
import '../../features/admin/settings/presentation/admin_settings_index_page.dart';
import '../../features/admin/settings/presentation/admin_setting_category_page.dart';
import '../../features/settings/servers_screen.dart';
import '../../features/settings/accounts_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/settings/logs_page.dart';
import '../../features/shell/home_shell.dart';
import '../../features/shell/me_tab.dart';
import '../../features/shell/splash_screen.dart';
import '../../features/user/dashboard/presentation/dashboard_tab.dart';
import '../../features/user/keys/presentation/keys_tab.dart';
import '../../features/user/keys/presentation/key_detail_page.dart';
import '../../features/user/profile/presentation/change_password_page.dart';
import '../../features/user/profile/presentation/bindings_page.dart';
import '../../features/user/profile/presentation/profile_page.dart';
import '../../features/user/profile/presentation/totp_manage_page.dart';
import '../../features/user/announcements/presentation/announcements_page.dart';
import '../../features/user/announcements/presentation/announcement_detail_page.dart';
import '../../features/user/announcements/data/announcements_api.dart';
import '../../features/user/redeem/presentation/redeem_page.dart';
import '../../features/user/recharge/presentation/recharge_page.dart';
import '../../features/user/affiliate/presentation/affiliate_page.dart';
import '../../features/user/channels_view/presentation/channels_page.dart';
import '../../features/user/channels_view/presentation/channel_status_page.dart';
import '../../features/user/channels_view/presentation/monitor_detail_page.dart';
import '../../features/user/subscriptions/presentation/subscriptions_page.dart';
import '../../features/user/usage/presentation/usage_tab.dart';
import '../../features/user/usage_logs/presentation/usage_logs_page.dart';
import '../../features/user/usage_logs/presentation/log_detail_page.dart';
import '../app_mode/app_mode_controller.dart';
import '../session/session_controller.dart';

/// 会话状态变化时通知 GoRouter 重新评估 redirect。
class _SessionRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}

/// 应用路由表(集中注册)+ 登录态守卫。
final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _SessionRefreshNotifier();
  ref.listen(sessionControllerProvider, (_, _) => notifier.refresh());
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: (context, state) {
      final session = ref.read(sessionControllerProvider);
      final location = state.matchedLocation;

      // 登录前后都可访问的页面
      const open = {'/servers', '/settings', '/logs'};
      if (open.contains(location)) return null;

      switch (session.status) {
        case SessionStatus.restoring:
          return location == '/splash' ? null : '/splash';
        case SessionStatus.unauthenticated:
          final allowed = location == '/login' || location == '/register';
          return allowed ? null : '/login';
        case SessionStatus.authenticated:
          // 已登录:启动闪屏按账号记忆的界面(用户端/管理端)落地;
          // /login、/register 保持可达(用于新增账号)。
          if (location == '/splash') {
            final mode = ref.read(appModeControllerProvider);
            return (mode == AppMode.admin && session.isAdmin)
                ? '/admin/dashboard'
                : '/dashboard';
          }
          if (location.startsWith('/admin') && !session.isAdmin) {
            return '/dashboard';
          }
          return null;
      }
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) =>
            RegisterScreen(serverId: state.extra as String?),
      ),
      GoRoute(
        path: '/servers',
        builder: (context, state) => const ServersScreen(),
      ),
      GoRoute(
        path: '/accounts',
        builder: (context, state) => const AccountsScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/logs',
        builder: (context, state) => const LogsPage(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfilePage(),
        routes: [
          GoRoute(
            path: 'change-password',
            builder: (context, state) => const ChangePasswordPage(),
          ),
          GoRoute(
            path: 'totp',
            builder: (context, state) => const TotpManagePage(),
          ),
          GoRoute(
            path: 'bindings',
            builder: (context, state) => const BindingsPage(),
          ),
        ],
      ),
      GoRoute(
        path: '/redeem',
        builder: (context, state) => const RedeemPage(),
      ),
      GoRoute(
        path: '/announcements',
        builder: (context, state) => const AnnouncementsPage(),
      ),
      GoRoute(
        path: '/announcements/:id',
        builder: (context, state) {
          final extra = state.extra;
          // 详情数据通过 extra 传入(列表已持有);无 extra(深链)时回退到列表。
          if (extra is UserAnnouncement) {
            return AnnouncementDetailPage(announcement: extra);
          }
          return const AnnouncementsPage();
        },
      ),
      // 可选开启的功能页面(占位,完整页见 P5–P7)。入口仅在管理员开启对应开关时展示。
      GoRoute(
        path: '/recharge',
        builder: (context, state) => const RechargePage(),
      ),
      GoRoute(
        path: '/affiliate',
        builder: (context, state) => const AffiliatePage(),
      ),
      GoRoute(
        path: '/channels',
        builder: (context, state) => const ChannelsPage(),
      ),
      GoRoute(
        path: '/channel-status',
        builder: (context, state) => const ChannelStatusPage(),
      ),
      GoRoute(
        path: '/channel-status/:id',
        builder: (context, state) => MonitorDetailPage(
          monitorId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/subscriptions',
        builder: (context, state) => const SubscriptionsPage(),
      ),
      GoRoute(
        path: '/usage-logs',
        builder: (context, state) => const UsageLogsPage(),
      ),
      GoRoute(
        path: '/usage/logs/:id',
        builder: (context, state) => LogDetailPage(
          logId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/keys/:id',
        builder: (context, state) => KeyDetailPage(
          keyId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/admin',
        redirect: (context, state) =>
            state.matchedLocation == '/admin' ? '/admin/dashboard' : null,
      ),
      // 管理端按需推入的子页(占位,完整页见 Phase D)。
      GoRoute(
        path: '/admin/redeem',
        builder: (context, state) => const RedeemListPage(),
      ),
      GoRoute(
        path: '/admin/monitor',
        builder: (context, state) => const MonitorListPage(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (context, state) => admin_monitor.MonitorDetailPage(
              monitorId: int.parse(state.pathParameters['id']!),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/admin/settings',
        builder: (context, state) => const AdminSettingsIndexPage(),
      ),
      GoRoute(
        path: '/admin/settings/:category',
        builder: (context, state) => AdminSettingCategoryPage(
          categoryKey: state.pathParameters['category'] ?? '',
        ),
      ),
      // 其余管理模块(对照 web 侧边栏);未实装先占位,逐步替换为真实页面。
      GoRoute(
        path: '/admin/accounts/new',
        builder: (context, state) => const AccountEditPage(),
      ),
      GoRoute(
        path: '/admin/accounts/:id/edit',
        builder: (context, state) => AccountEditPage(
          accountId: int.tryParse(state.pathParameters['id'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/admin/accounts/:id',
        builder: (context, state) => AccountDetailPage(
          accountId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/admin/ops',
        builder: (context, state) => const OpsPage(),
      ),
      GoRoute(
        path: '/admin/channels',
        builder: (context, state) => const ChannelsListPage(),
      ),
      GoRoute(
        path: '/admin/channels/new',
        builder: (context, state) => const ChannelEditPage(),
      ),
      GoRoute(
        path: '/admin/channels/:id/edit',
        builder: (context, state) => ChannelEditPage(
          channelId: int.tryParse(state.pathParameters['id'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/admin/subscriptions',
        builder: (context, state) => const SubscriptionsListPage(),
      ),
      GoRoute(
        path: '/admin/announcements-admin',
        builder: (context, state) => const AnnouncementsListPage(),
      ),
      GoRoute(
        path: '/admin/announcements-admin/new',
        builder: (context, state) => const AnnouncementEditPage(),
      ),
      GoRoute(
        path: '/admin/announcements-admin/:id/edit',
        builder: (context, state) => AnnouncementEditPage(
          announcementId: int.tryParse(state.pathParameters['id'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/admin/announcements-admin/:id/read-status',
        builder: (context, state) => AnnouncementReadStatusPage(
          announcementId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/admin/proxies',
        builder: (context, state) => const ProxyListPage(),
      ),
      GoRoute(
        path: '/admin/proxies/new',
        builder: (context, state) => const ProxyEditPage(),
      ),
      GoRoute(
        path: '/admin/proxies/:id/edit',
        builder: (context, state) => ProxyEditPage(
          proxyId: int.tryParse(state.pathParameters['id'] ?? ''),
          initial: state.extra is Proxy ? state.extra as Proxy : null,
        ),
      ),
      GoRoute(
        path: '/admin/risk-control',
        builder: (context, state) => const RiskControlPage(),
      ),
      GoRoute(
        path: '/admin/risk-control/config',
        builder: (context, state) => const RiskConfigPage(),
      ),
      GoRoute(
        path: '/admin/promo-codes',
        builder: (context, state) => const PromoListPage(),
      ),
      GoRoute(
        path: '/admin/promo-codes/:id/usages',
        builder: (context, state) => PromoUsagesPage(
          codeId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/admin/affiliates',
        builder: (context, state) => const AdminAffiliatesPage(),
      ),
      GoRoute(
        path: '/admin/orders',
        builder: (context, state) => const AdminOrdersPage(),
      ),
      GoRoute(
        path: '/admin/orders/plans/new',
        builder: (context, state) => const PlanEditPage(),
      ),
      GoRoute(
        path: '/admin/orders/plans/:id/edit',
        builder: (context, state) => PlanEditPage(
          planId: int.tryParse(state.pathParameters['id'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/admin/usage',
        builder: (context, state) => const AdminUsageListPage(),
      ),
      GoRoute(
        path: '/admin/usage/cleanup',
        builder: (context, state) => const AdminUsageCleanupPage(),
      ),
      // 登录后的主壳:底部导航四个分支
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/dashboard',
              builder: (context, state) => const DashboardTab(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/keys',
              builder: (context, state) => const KeysTab(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/usage',
              builder: (context, state) => const UsageTab(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/me',
              builder: (context, state) => const MeTab(),
            ),
          ]),
        ],
      ),
      // 管理端主壳:底部导航 概览/账号池/用户/分组/更多(仅管理员可达,redirect 守卫)。
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AdminShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/admin/dashboard',
              builder: (context, state) => const AdminDashboardTab(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/admin/accounts',
              builder: (context, state) => const AccountsListPage(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/admin/users',
              builder: (context, state) => const UsersListPage(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (context, state) => UserDetailPage(
                    userId: int.parse(state.pathParameters['id']!),
                  ),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/admin/groups',
              builder: (context, state) => const GroupsListPage(),
              routes: [
                GoRoute(
                  path: 'new',
                  builder: (context, state) => const GroupEditPage(),
                ),
                GoRoute(
                  path: ':id',
                  builder: (context, state) => GroupEditPage(
                    groupId: int.parse(state.pathParameters['id']!),
                  ),
                  routes: [
                    GoRoute(
                      path: 'rates',
                      builder: (context, state) => GroupRatesPage(
                        groupId: int.parse(state.pathParameters['id']!),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/admin/more',
              builder: (context, state) => const AdminMoreTab(),
            ),
          ]),
        ],
      ),
    ],
  );
});
