import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/session/session_controller.dart';
import '../../../../i18n/app_localizations.dart';
import '../providers/profile_providers.dart';

/// 个人资料页:改密、TOTP、未来可扩展其他资料编辑。
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionControllerProvider).user;
    final totpAsync = ref.watch(totpStatusProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('profile.title'))),
      body: ListView(
        children: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('profile.accountInfo'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      _InfoRow(
                        label: context.tr('auth.email'),
                        value: user.email,
                      ),
                      const SizedBox(height: 8),
                      _InfoRow(
                        label: context.tr('profile.balance'),
                        value: '\$${user.balance.toStringAsFixed(2)}',
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
            error: (_, __) => ListTile(
              leading: const Icon(Icons.security_outlined),
              title: Text(context.tr('profile.totp')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/profile/totp'),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
