import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../i18n/app_localizations.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../../shared/widgets/error_retry.dart';
import '../../../../shared/widgets/responsive.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../data/admin_accounts_api.dart';
import '../providers/admin_accounts_providers.dart';

/// 账号详情:完整信息 + 全部操作(启停/测试/清错/清限流/刷新/删除)。
class AccountDetailPage extends ConsumerWidget {
  const AccountDetailPage({super.key, required this.accountId});

  final int accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminAccountDetailProvider(accountId));
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('adminAccounts.detailTitle'))),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorRetryView(
          error: e,
          onRetry: () => ref.invalidate(adminAccountDetailProvider(accountId)),
        ),
        data: (a) => _Detail(account: a),
      ),
    );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({required this.account});

  final AdminAccount account;

  StatusTone get _tone => switch (account.status) {
        'active' => StatusTone.positive,
        'error' => StatusTone.danger,
        _ => StatusTone.neutral,
      };

  String _statusKey() => switch (account.status) {
        'active' => 'adminAccounts.statusActive',
        'error' => 'adminAccounts.statusError',
        _ => 'adminAccounts.statusInactive',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = account;
    return ResponsiveCenter(
      maxWidth: 720,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(a.name,
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              StatusPill(label: context.tr(_statusKey()), tone: _tone),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  _row(context, 'adminAccounts.platform', a.platform),
                  _row(context, 'adminAccounts.type', a.type),
                  _row(context, 'adminAccounts.concurrency',
                      '${a.currentConcurrency}/${a.concurrency}'),
                  _row(context, 'adminAccounts.priority', '${a.priority}'),
                  if (a.rateMultiplier != null)
                    _row(context, 'adminAccounts.rateMultiplier',
                        '×${a.rateMultiplier!.toStringAsFixed(2)}'),
                  _row(context, 'adminAccounts.schedulable',
                      context.tr(a.schedulable ? 'common.yes' : 'common.no')),
                  if (a.groupNames.isNotEmpty)
                    _row(context, 'adminAccounts.groups',
                        a.groupNames.join(', ')),
                  if ((a.lastUsedAt ?? '').isNotEmpty)
                    _row(context, 'adminAccounts.lastUsed', a.lastUsedAt!),
                  if ((a.notes ?? '').isNotEmpty)
                    _row(context, 'adminAccounts.notes', a.notes!),
                ],
              ),
            ),
          ),
          if (a.isError && (a.errorMessage ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  a.errorMessage!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.tonalIcon(
                icon: Icon(a.isActive ? Icons.pause : Icons.play_arrow),
                label: Text(context.tr(
                    a.isActive ? 'adminAccounts.disable' : 'adminAccounts.enable')),
                onPressed: () => _do(context, ref,
                    () => _api(ref).setStatus(a.id, !a.isActive)),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.wifi_tethering),
                label: Text(context.tr('adminAccounts.test')),
                onPressed: () => _test(context, ref),
              ),
              if (a.isError)
                OutlinedButton.icon(
                  icon: const Icon(Icons.cleaning_services_outlined),
                  label: Text(context.tr('adminAccounts.clearError')),
                  onPressed: () =>
                      _do(context, ref, () => _api(ref).clearError(a.id)),
                ),
              OutlinedButton.icon(
                icon: const Icon(Icons.speed_outlined),
                label: Text(context.tr('adminAccounts.clearRateLimit')),
                onPressed: () =>
                    _do(context, ref, () => _api(ref).clearRateLimit(a.id)),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh),
                label: Text(context.tr('adminAccounts.refresh')),
                onPressed: () =>
                    _do(context, ref, () => _api(ref).refreshCredentials(a.id)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: Icon(Icons.delete_outline,
                color: Theme.of(context).colorScheme.error),
            label: Text(
              context.tr('adminAccounts.delete'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onPressed: () => _delete(context, ref),
          ),
        ],
      ),
    );
  }

  AdminAccountsApi _api(WidgetRef ref) => ref.read(adminAccountsApiProvider);

  Future<void> _do(
      BuildContext context, WidgetRef ref, Future<void> Function() op) async {
    try {
      await op();
      ref.invalidate(adminAccountDetailProvider(account.id));
      ref.invalidate(adminAccountsControllerProvider);
      if (context.mounted) showAppToast(context, context.tr('common.done'));
    } catch (e) {
      if (context.mounted) showAppToast(context, '$e', error: true);
    }
  }

  Future<void> _test(BuildContext context, WidgetRef ref) async {
    showAppToast(context, context.tr('adminAccounts.testing'));
    try {
      final r = await _api(ref).test(account.id);
      if (context.mounted) {
        showAppToast(
          context,
          r.latencyMs != null ? '${r.message} (${r.latencyMs}ms)' : r.message,
          error: !r.success,
        );
      }
    } catch (e) {
      if (context.mounted) showAppToast(context, '$e', error: true);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(
      context,
      title: context.tr('adminAccounts.delete'),
      message:
          context.tr('adminAccounts.deleteConfirm', params: {'name': account.name}),
      confirmLabel: context.tr('common.delete'),
      destructive: true,
    );
    if (!ok) return;
    try {
      await _api(ref).delete(account.id);
      ref.invalidate(adminAccountsControllerProvider);
      if (context.mounted) context.pop();
    } catch (e) {
      if (context.mounted) showAppToast(context, '$e', error: true);
    }
  }

  Widget _row(BuildContext context, String labelKey, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              context.tr(labelKey),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
