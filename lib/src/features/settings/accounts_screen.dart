import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/account/account_profile.dart';
import '../../core/account/account_store.dart';
import '../../core/server/server_store.dart';
import '../../core/session/session_controller.dart';
import '../../i18n/app_localizations.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/user_avatar.dart';

/// 账号管理页:多账号列表(切换/登出/删除)+ 添加账号。
class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountState = ref.watch(accountStoreProvider);
    final servers = ref.watch(serverStoreProvider).servers;
    final accounts = accountState.accounts;

    String serverName(String serverId) {
      for (final s in servers) {
        if (s.id == serverId) return s.name;
      }
      return serverId;
    }

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('accounts.title'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/login'),
        icon: const Icon(Icons.person_add_alt),
        label: Text(context.tr('accounts.addAccount')),
      ),
      body: accounts.isEmpty
          ? EmptyState(
              icon: Icons.account_circle_outlined,
              message: context.tr('accounts.empty'),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
              children: [
                for (final account in accounts)
                  _AccountCard(
                    account: account,
                    serverName: serverName(account.serverId),
                    active: account.id == accountState.activeId,
                    onTap: account.id == accountState.activeId
                        ? null
                        : () => ref
                            .read(sessionControllerProvider.notifier)
                            .switchAccount(account.id),
                    onLogout: () => _logout(context, ref),
                    onRemove: () => _remove(context, ref, account),
                  ),
              ],
            ),
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: context.tr('accounts.logoutThis'),
      message: context.tr('me.logoutConfirm'),
      confirmLabel: context.tr('auth.logout'),
      destructive: true,
    );
    if (confirmed) {
      await ref.read(sessionControllerProvider.notifier).logout();
    }
  }

  Future<void> _remove(
      BuildContext context, WidgetRef ref, AccountProfile account) async {
    final confirmed = await showConfirmDialog(
      context,
      title: context.tr('accounts.remove'),
      message:
          context.tr('accounts.removeConfirm', params: {'email': account.email}),
      confirmLabel: context.tr('common.delete'),
      destructive: true,
    );
    if (confirmed) {
      await ref
          .read(sessionControllerProvider.notifier)
          .removeAccount(account.id);
    }
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.account,
    required this.serverName,
    required this.active,
    required this.onTap,
    required this.onLogout,
    required this.onRemove,
  });

  final AccountProfile account;
  final String serverName;
  final bool active;
  final VoidCallback? onTap;
  final VoidCallback onLogout;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: active ? scheme.primary : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundImage: avatarImageProvider(account.avatarUrl),
                child: avatarImageProvider(account.avatarUrl) == null
                    ? Text((account.email.isNotEmpty ? account.email[0] : '?')
                        .toUpperCase())
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            account.email,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (active) ...[
                          const SizedBox(width: 8),
                          _ActiveChip(label: context.tr('accounts.active')),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      serverName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (v) {
                  if (v == 'logout') onLogout();
                  if (v == 'remove') onRemove();
                },
                itemBuilder: (context) => [
                  if (active)
                    PopupMenuItem(
                      value: 'logout',
                      child: Text(context.tr('accounts.logoutThis')),
                    ),
                  PopupMenuItem(
                    value: 'remove',
                    child: Text(context.tr('accounts.remove')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveChip extends StatelessWidget {
  const _ActiveChip({required this.label});

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
