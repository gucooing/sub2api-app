import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/session/auth_models.dart';
import '../../../../core/session/session_controller.dart';
import '../../../../i18n/app_localizations.dart';
import '../../../../shared/format/formatters.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../shared/widgets/section_header.dart';
import '../providers/profile_providers.dart';

/// 个人资料页:展示账户信息(余额/并发/注册时间),并可改用户名/头像/
/// 余额提醒/密码/两步验证。
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionControllerProvider).user;
    final totpAsync = ref.watch(totpStatusProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('profile.title'))),
      body: user == null
          ? const SizedBox.shrink()
          : ListView(
              children: [
                _InfoCard(user: user),
                SectionHeader(title: context.tr('profile.account')),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(context.tr('profile.username')),
                  subtitle: Text(user.username),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => _editUsername(context, ref, user.username),
                ),
                ListTile(
                  leading: const Icon(Icons.image_outlined),
                  title: Text(context.tr('profile.avatar')),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => _editAvatar(context, ref, user.avatarUrl ?? ''),
                ),
                _BalanceNotifyTile(user: user),
                SectionHeader(title: context.tr('profile.security')),
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: Text(context.tr('profile.changePassword')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/profile/change-password'),
                ),
                totpAsync.when(
                  data: (status) => ListTile(
                    leading: Icon(
                      status.enabled
                          ? Icons.verified_user
                          : Icons.security_outlined,
                    ),
                    title: Text(context.tr('profile.totp')),
                    subtitle: Text(
                      status.enabled
                          ? context.tr('profile.totpEnabled')
                          : context.tr('profile.totpDisabled'),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/profile/totp'),
                  ),
                  loading: () => ListTile(
                    leading: const Icon(Icons.security_outlined),
                    title: Text(context.tr('profile.totp')),
                    trailing: const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  error: (_, _) => ListTile(
                    leading: const Icon(Icons.security_outlined),
                    title: Text(context.tr('profile.totp')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/profile/totp'),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
    );
  }

  Future<void> _editUsername(
      BuildContext context, WidgetRef ref, String current) async {
    final value = await _promptText(
      context,
      title: context.tr('profile.editUsername'),
      label: context.tr('profile.username'),
      initial: current,
    );
    if (value == null || value.trim().isEmpty || value.trim() == current) {
      return;
    }
    if (!context.mounted) return;
    await _save(context, ref, () =>
        ref.read(profileApiProvider).updateProfile(username: value.trim()));
  }

  Future<void> _editAvatar(
      BuildContext context, WidgetRef ref, String current) async {
    final value = await _promptText(
      context,
      title: context.tr('profile.editAvatar'),
      label: context.tr('profile.avatarUrlHint'),
      initial: current,
      keyboardType: TextInputType.url,
    );
    if (value == null) return;
    final trimmed = value.trim();
    if (!context.mounted) return;
    await _save(
      context,
      ref,
      () => ref
          .read(profileApiProvider)
          .updateProfile(avatarUrl: trimmed.isEmpty ? null : trimmed),
    );
  }
}

/// 执行一次资料更新并刷新会话用户,成功后顶部 toast 提示。
Future<void> _save(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function() action,
) async {
  try {
    await action();
    await ref.read(sessionControllerProvider.notifier).refreshUser();
    if (context.mounted) showAppToast(context, context.tr('profile.saved'));
  } catch (_) {
    if (context.mounted) {
      showAppToast(context, context.tr('common.unknownError'), error: true);
    }
  }
}

Future<String?> _promptText(
  BuildContext context, {
  required String title,
  required String label,
  String initial = '',
  TextInputType? keyboardType,
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (v) => Navigator.of(ctx).pop(v),
      ),
      actions: [
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: () => Navigator.of(ctx).pop(controller.text),
          child: Text(ctx.tr('common.save')),
        ),
        OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(ctx.tr('common.cancel')),
        ),
      ],
    ),
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final avatar = user.avatarUrl;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundImage: (avatar != null && avatar.isNotEmpty)
                        ? NetworkImage(avatar)
                        : null,
                    child: (avatar == null || avatar.isEmpty)
                        ? Text(
                            (user.username.isNotEmpty
                                    ? user.username[0]
                                    : user.email.isNotEmpty
                                        ? user.email[0]
                                        : '?')
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
                          user.username.isNotEmpty ? user.username : user.email,
                          style: Theme.of(context).textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.email,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              _InfoRow(
                label: context.tr('profile.balance'),
                value: '\$${user.balance.toStringAsFixed(2)}',
                emphasize: true,
              ),
              const SizedBox(height: 8),
              _InfoRow(
                label: context.tr('profile.concurrency'),
                value: user.concurrency > 0 ? '${user.concurrency}' : '—',
              ),
              const SizedBox(height: 8),
              _InfoRow(
                label: context.tr('profile.registeredAt'),
                value: user.createdAt != null
                    ? formatDate(user.createdAt!)
                    : '—',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 余额不足提醒:开关 + 阈值编辑。
class _BalanceNotifyTile extends ConsumerWidget {
  const _BalanceNotifyTile({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threshold = user.balanceNotifyThreshold;
    return Column(
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.notifications_active_outlined),
          title: Text(context.tr('profile.balanceNotify')),
          subtitle: Text(context.tr('profile.balanceNotifyHint')),
          value: user.balanceNotifyEnabled,
          onChanged: (v) => _save(
            context,
            ref,
            () => ref
                .read(profileApiProvider)
                .updateProfile(balanceNotifyEnabled: v),
          ),
        ),
        if (user.balanceNotifyEnabled)
          ListTile(
            contentPadding: const EdgeInsets.only(left: 72, right: 16),
            title: Text(context.tr('profile.balanceNotifyThreshold')),
            trailing: Text(
              threshold != null ? '\$${threshold.toStringAsFixed(2)}' : '—',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            onTap: () => _editThreshold(context, ref, threshold),
          ),
      ],
    );
  }

  Future<void> _editThreshold(
      BuildContext context, WidgetRef ref, double? current) async {
    final value = await _promptText(
      context,
      title: context.tr('profile.balanceNotifyThreshold'),
      label: context.tr('profile.balanceNotifyThreshold'),
      initial: current?.toStringAsFixed(2) ?? '',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
    );
    if (value == null) return;
    final parsed = double.tryParse(value.trim());
    if (!context.mounted) return;
    await _save(
      context,
      ref,
      () => ref
          .read(profileApiProvider)
          .updateProfile(balanceNotifyThreshold: parsed),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: emphasize
                ? Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    )
                : Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
