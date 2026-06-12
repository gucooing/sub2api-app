import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../i18n/app_localizations.dart';

/// 登录后的主导航壳:底部导航 总览/密钥/用量/我的。
/// 各 tab 内容由 StatefulShellRoute 的分支路由提供。
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.dashboard_outlined),
            selectedIcon: const Icon(Icons.dashboard),
            label: context.tr('nav.dashboard'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.vpn_key_outlined),
            selectedIcon: const Icon(Icons.vpn_key),
            label: context.tr('nav.keys'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.insights_outlined),
            selectedIcon: const Icon(Icons.insights),
            label: context.tr('nav.usage'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: context.tr('nav.me'),
          ),
        ],
      ),
    );
  }
}
