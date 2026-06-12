import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../i18n/app_localizations.dart';
import '../user/announcements/providers/announcements_providers.dart';

/// 登录后的主导航壳:底部导航 总览/密钥/用量/我的。
/// 各 tab 内容由 StatefulShellRoute 的分支路由提供。
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  bool _hasShownDialog = false;

  @override
  void initState() {
    super.initState();
    // 延迟检查未读公告
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUnreadAnnouncements();
    });
  }

  Future<void> _checkUnreadAnnouncements() async {
    if (_hasShownDialog) return;

    try {
      final unread = await ref.read(unreadAnnouncementsProvider.future);
      if (unread.isNotEmpty && mounted) {
        _hasShownDialog = true;
        _showAnnouncementDialog(unread.first);
      }
    } catch (_) {
      // 静默失败
    }
  }

  void _showAnnouncementDialog(announcement) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.campaign, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(announcement.title)),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(announcement.content),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              // 标记为已读
              try {
                await ref
                    .read(announcementsApiProvider)
                    .markRead(announcement.id);
                ref.invalidate(unreadAnnouncementsProvider);
              } catch (_) {}
            },
            child: Text(context.tr('common.close')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = ref.watch(unreadAnnouncementsCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle(context)),
        actions: [
          unreadCount.when(
            data: (count) => count > 0
                ? Badge(
                    label: Text('$count'),
                    child: IconButton(
                      icon: const Icon(Icons.notifications_outlined),
                      onPressed: () => context.push('/announcements'),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () => context.push('/announcements'),
                  ),
            loading: () => IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () => context.push('/announcements'),
            ),
            error: (_, __) => IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () => context.push('/announcements'),
            ),
          ),
        ],
      ),
      body: widget.navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.navigationShell.currentIndex,
        onDestinationSelected: (index) => widget.navigationShell.goBranch(
          index,
          initialLocation: index == widget.navigationShell.currentIndex,
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

  String _getTitle(BuildContext context) {
    return switch (widget.navigationShell.currentIndex) {
      0 => context.tr('nav.dashboard'),
      1 => context.tr('nav.keys'),
      2 => context.tr('nav.usage'),
      3 => context.tr('nav.me'),
      _ => '',
    };
  }
}
