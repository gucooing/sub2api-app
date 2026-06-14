import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_mode/app_mode_controller.dart';
import '../../../i18n/app_localizations.dart';

/// 管理端主壳:底部导航 概览/账号池/用户/分组/更多。
///
/// 与用户端 [HomeShell] 平级,是「另一套主界面」;右上角可一键切回用户端。
/// 各 tab 内容由 StatefulShellRoute 的分支路由提供。
class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _titleKeys = [
    'admin.nav.dashboard',
    'admin.nav.accounts',
    'admin.nav.users',
    'admin.nav.groups',
    'admin.nav.more',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = navigationShell.currentIndex;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr(_titleKeys[index])),
        actions: [
          // 一键切回用户端(管理端是临时进入的「另一套界面」)。
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: TextButton.icon(
              icon: const Icon(Icons.swap_horiz, size: 18),
              label: Text(context.tr('admin.switchToUser')),
              onPressed: () async {
                await ref
                    .read(appModeControllerProvider.notifier)
                    .setMode(AppMode.user);
                if (context.mounted) context.go('/dashboard');
              },
            ),
          ),
        ],
      ),
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
        ),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.space_dashboard_outlined),
            selectedIcon: const Icon(Icons.space_dashboard),
            label: context.tr('admin.nav.dashboard'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.cloud_outlined),
            selectedIcon: const Icon(Icons.cloud),
            label: context.tr('admin.nav.accounts'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.group_outlined),
            selectedIcon: const Icon(Icons.group),
            label: context.tr('admin.nav.users'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.workspaces_outline),
            selectedIcon: const Icon(Icons.workspaces),
            label: context.tr('admin.nav.groups'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.more_horiz),
            label: context.tr('admin.nav.more'),
          ),
        ],
      ),
    );
  }
}
