import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_mode/app_mode_controller.dart';
import '../../../core/session/session_controller.dart';
import '../../../i18n/app_localizations.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/responsive.dart';

/// 管理端「更多」:其余管理模块入口 + 切回用户端 + 设置 + 退出登录。
class AdminMoreTab extends ConsumerWidget {
  const AdminMoreTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionControllerProvider).user;
    return ResponsiveCenter(
      maxWidth: 640,
      child: ListView(
        children: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                user.email,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          _GroupHeader(context.tr('admin.nav.more')),
          ListTile(
            leading: const Icon(Icons.card_giftcard_outlined),
            title: Text(context.tr('admin.redeem.title')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/admin/redeem'),
          ),
          ListTile(
            leading: const Icon(Icons.monitor_heart_outlined),
            title: Text(context.tr('admin.monitor.title')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/admin/monitor'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.swap_horiz),
            title: Text(context.tr('admin.switchToUser')),
            subtitle: Text(context.tr('admin.switchToUserHint')),
            onTap: () async {
              await ref
                  .read(appModeControllerProvider.notifier)
                  .setMode(AppMode.user);
              if (context.mounted) context.go('/dashboard');
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: Text(context.tr('nav.settings')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings'),
          ),
          const Divider(),
          ListTile(
            leading: Icon(
              Icons.logout,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              context.tr('auth.logout'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () => _confirmLogout(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: context.tr('auth.logout'),
      message: context.tr('me.logoutConfirm'),
      confirmLabel: context.tr('auth.logout'),
      destructive: true,
    );
    if (confirmed) {
      await ref.read(sessionControllerProvider.notifier).logout();
    }
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
