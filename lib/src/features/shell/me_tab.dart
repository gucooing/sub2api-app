import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/server/server_store.dart';
import '../../core/session/session_controller.dart';
import '../../i18n/app_localizations.dart';

/// 「我的」tab:用户信息卡 + 各入口(资料/服务器/设置/管理端)+ 退出登录。
class MeTab extends ConsumerWidget {
  const MeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final server = ref.watch(activeServerProvider);
    final user = session.user;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('nav.me'))),
      body: ListView(
        children: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        child: Text(
                          (user.email.isNotEmpty ? user.email[0] : '?')
                              .toUpperCase(),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.email,
                              style: Theme.of(context).textTheme.titleMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                if (user.isAdmin) ...[
                                  _RoleChip(
                                      label: context.tr('me.roleAdmin')),
                                  const SizedBox(width: 8),
                                ],
                                Flexible(
                                  child: Text(
                                    server.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              context.tr('me.balance', params: {
                                'amount': user.balance.toStringAsFixed(2)
                              }),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: Text(context.tr('me.profile')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/profile'),
          ),
          ListTile(
            leading: const Icon(Icons.card_membership_outlined),
            title: Text(context.tr('nav.subscriptions')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/subscriptions'),
          ),
          ListTile(
            leading: const Icon(Icons.card_giftcard_outlined),
            title: Text(context.tr('redeem.title')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/redeem'),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: Text(context.tr('announcements.title')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/announcements'),
          ),
          if (session.isAdmin)
            ListTile(
              leading: const Icon(Icons.admin_panel_settings_outlined),
              title: Text(context.tr('nav.admin')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/admin'),
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: Text(context.tr('servers.title')),
            subtitle: Text(server.name),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/servers'),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('auth.logout')),
        content: Text(context.tr('me.logoutConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('common.cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.tr('auth.logout')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(sessionControllerProvider.notifier).logout();
    }
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: scheme.onPrimaryContainer),
      ),
    );
  }
}
