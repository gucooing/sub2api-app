import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/account/account_store.dart';
import '../../core/app_mode/app_mode_controller.dart';
import '../../core/server/server_store.dart';
import '../../core/session/auth_models.dart';
import '../../core/session/session_controller.dart';
import '../../i18n/app_localizations.dart';
import '../user/features/data/user_features.dart';
import '../user/features/presentation/custom_page_launcher.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/responsive.dart';
import '../../shared/widgets/user_avatar.dart';

/// 「我的」tab:用户信息卡 + 各入口(资料/服务器/设置/管理端)+ 退出登录。
class MeTab extends ConsumerWidget {
  const MeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final server = ref.watch(activeServerProvider);
    final account = ref.watch(activeAccountProvider);
    final servers = ref.watch(serverStoreProvider).servers;
    // 当前账号所在服务器名(账号与服务器解耦,优先按账号取)。
    final accountServerName = account == null
        ? server.name
        : servers
            .firstWhere(
              (s) => s.id == account.serverId,
              orElse: () => server,
            )
            .name;
    final user = session.user;
    final publicSettings = ref.watch(publicSettingsProvider).value;
    final features = publicSettings == null
        ? const <UserFeature>[]
        : enabledUserFeatures(publicSettings);
    final customPages = publicSettings == null
        ? const <CustomMenuItem>[]
        : visibleCustomPages(publicSettings, isAdmin: session.isAdmin);

    return Scaffold(
      body: ResponsiveCenter(
        maxWidth: 640,
        child: ListView(
        children: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: InkWell(
                  onTap: () => context.push('/profile'),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundImage: avatarImageProvider(user.avatarUrl),
                          child: avatarImageProvider(user.avatarUrl) == null
                              ? Text(
                                  (user.email.isNotEmpty ? user.email[0] : '?')
                                      .toUpperCase(),
                                  style: Theme.of(context).textTheme.titleLarge,
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.email,
                                style:
                                    Theme.of(context).textTheme.titleMedium,
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
                                      accountServerName,
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
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ListTile(
            leading: const Icon(Icons.link_outlined),
            title: Text(context.tr('bindings.title')),
            subtitle: Text(context.tr('bindings.subtitle')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/profile/bindings'),
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
          ListTile(
            leading: const Icon(Icons.list_alt_outlined),
            title: Text(context.tr('usageLogs.title')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/usage-logs'),
          ),
          // 管理员开启的可选功能入口。
          if (features.isNotEmpty) ...[
            const Divider(),
            _GroupHeader(context.tr('features.section')),
            for (final f in features)
              ListTile(
                leading: Icon(f.icon),
                title: Text(context.tr(f.labelKey)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(f.route),
              ),
          ],
          // 管理员配置的自定义页面(点击在浏览器中打开)。
          if (customPages.isNotEmpty) ...[
            const Divider(),
            _GroupHeader(context.tr('features.customPages')),
            for (final p in customPages)
              ListTile(
                leading: const Icon(Icons.public_outlined),
                title: Text(p.label),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => openCustomPage(context, ref, p),
              ),
          ],
          if (session.isAdmin)
            ListTile(
              leading: const Icon(Icons.admin_panel_settings_outlined),
              title: Text(context.tr('admin.switchToAdmin')),
              subtitle: Text(context.tr('admin.switchToAdminHint')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await ref
                    .read(appModeControllerProvider.notifier)
                    .setMode(AppMode.admin);
                if (context.mounted) context.go('/admin/dashboard');
              },
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.manage_accounts_outlined),
            title: Text(context.tr('accounts.title')),
            subtitle: Text(user != null
                ? '${user.email} · $accountServerName'
                : accountServerName),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/accounts'),
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
