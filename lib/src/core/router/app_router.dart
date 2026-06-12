import 'package:go_router/go_router.dart';

import '../../features/home/home_screen.dart';
import '../../features/settings/settings_screen.dart';

/// 应用路由表(go_router)。后续按功能新增登录、控制台、管理端等路由。
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);
