import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_mode/app_mode_controller.dart';
import '../../../core/config/app_config.dart';
import '../../../core/server/server_store.dart';
import '../../../core/session/auth_models.dart';
import '../../../core/session/session_controller.dart';
import '../../../i18n/app_localizations.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/responsive.dart';
import '../../user/features/data/user_features.dart';
import '../../user/features/presentation/custom_page_launcher.dart';
import '../shared/admin_modules.dart';

/// 管理端「更多」:站点信息(对应用户端用户信息)+ 其余管理模块入口 +
/// 自定义页面 + 切回用户端 + 设置 + 退出登录。
class AdminMoreTab extends ConsumerWidget {
  const AdminMoreTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(publicSettingsProvider).value;
    final server = ref.watch(activeServerProvider);
    final customPages = settings == null
        ? const <CustomMenuItem>[]
        : visibleCustomPages(settings, isAdmin: true);
    return ResponsiveCenter(
      maxWidth: 640,
      child: ListView(
        children: [
          // 站点信息卡(对应用户端顶部的用户信息卡)。
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      child: Icon(
                        Icons.dns_outlined,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (settings?.siteName.isNotEmpty ?? false)
                                ? settings!.siteName
                                : server.name,
                            style: Theme.of(context).textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            server.baseUrl,
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
                          if ((settings?.version ?? '').isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'v${settings!.version} · ${context.tr('settings.compatibleBackend')} v${AppConfig.compatibleBackendVersion}',
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
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _GroupHeader(context.tr('admin.nav.more')),
          for (final m in visibleAdminModules(settings))
            ListTile(
              leading: Icon(m.icon),
              title: Text(context.tr(m.labelKey)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(m.route),
            ),
          // 管理员配置的自定义页面(浏览器中打开)。
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
