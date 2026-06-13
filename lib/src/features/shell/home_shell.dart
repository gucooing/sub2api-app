import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../i18n/app_localizations.dart';
import '../../shared/widgets/markdown_text.dart';
import '../user/announcements/data/announcements_api.dart';
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
  /// 已弹过的 popup 公告 id(避免重复弹出)。
  final Set<int> _shownPopupIds = {};
  bool _popupShowing = false;

  @override
  void initState() {
    super.initState();
    // 启动即在总览页时检查 popup 公告。
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowPopup());
  }

  /// 切到总览页时:若有未读且为 popup 的公告,自动弹出(每条仅一次)。
  Future<void> _maybeShowPopup() async {
    if (_popupShowing) return;
    if (widget.navigationShell.currentIndex != 0) return;
    try {
      final unread = await ref.read(unreadAnnouncementsProvider.future);
      if (!mounted || widget.navigationShell.currentIndex != 0) return;
      UserAnnouncement? target;
      for (final a in unread) {
        if (a.isPopup && !_shownPopupIds.contains(a.id)) {
          target = a;
          break;
        }
      }
      if (target == null) return;
      _shownPopupIds.add(target.id);
      _popupShowing = true;
      await _showAnnouncementDialog(target);
      _popupShowing = false;
      // 关闭后若还有下一条 popup,继续弹。
      if (mounted) _maybeShowPopup();
    } catch (_) {
      _popupShowing = false;
    }
  }

  Future<void> _showAnnouncementDialog(UserAnnouncement announcement) {
    return showDialog<void>(
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
          child: MarkdownText(announcement.content),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await ref
                    .read(announcementsApiProvider)
                    .markRead(announcement.id);
                ref.invalidate(announcementsListProvider);
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
    final hasUnread = ref.watch(unreadAnnouncementsCountProvider).maybeWhen(
          data: (count) => count > 0,
          orElse: () => false,
        );
    // 在总览页时尝试弹出 popup 公告(set 去重,不会重复)。
    if (widget.navigationShell.currentIndex == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowPopup());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle(context)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Badge(
              // 无 label:有未读时显示小红点。
              isLabelVisible: hasUnread,
              child: IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () => context.push('/announcements'),
              ),
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
