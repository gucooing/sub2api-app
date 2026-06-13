import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/settings/servers_screen.dart';
import '../../features/settings/settings_screen.dart';
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
import '../../features/user/subscriptions/presentation/subscriptions_page.dart';
import '../../features/user/usage/presentation/usage_tab.dart';
import '../../features/user/usage_logs/presentation/usage_logs_page.dart';
import '../../features/user/usage_logs/presentation/log_detail_page.dart';
import '../../shared/widgets/module_placeholder.dart';
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
      const open = {'/servers', '/settings'};
      if (open.contains(location)) return null;

      switch (session.status) {
        case SessionStatus.restoring:
          return location == '/splash' ? null : '/splash';
        case SessionStatus.unauthenticated:
          final allowed = location == '/login' || location == '/register';
          return allowed ? null : '/login';
        case SessionStatus.authenticated:
          // 已登录:仅启动闪屏跳转到总览;/login、/register 保持可达(用于新增账号)。
          if (location == '/splash') {
            return '/dashboard';
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
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
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
        builder: (context, state) =>
            const ModulePlaceholderScreen(titleKey: 'features.affiliate'),
      ),
      GoRoute(
        path: '/channels',
        builder: (context, state) => const ModulePlaceholderScreen(
            titleKey: 'features.availableChannels'),
      ),
      GoRoute(
        path: '/channel-status',
        builder: (context, state) =>
            const ModulePlaceholderScreen(titleKey: 'features.channelStatus'),
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
        builder: (context, state) =>
            const ModulePlaceholderScreen(titleKey: 'nav.admin'),
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
    ],
  );
});
