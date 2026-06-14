import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../i18n/app_localizations.dart';
import '../../../../shared/format/formatters.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../../shared/widgets/error_retry.dart';
import '../../../../shared/widgets/responsive.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../data/admin_accounts_api.dart';
import '../providers/admin_accounts_providers.dart';
import 'accounts_list_page.dart';
import 'account_test_dialog.dart';

/// 账号详情:展示全部信息(紧凑 key-value)+ 编辑(AppBar 小图标)+ 类型相关操作菜单。
class AccountDetailPage extends ConsumerWidget {
  const AccountDetailPage({super.key, required this.accountId});

  final int accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminAccountDetailProvider(accountId));
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('adminAccounts.detailTitle')),
        actions: [
          async.maybeWhen(
            data: (a) => Row(children: [
              IconButton(
                tooltip: context.tr('common.edit'),
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => context.push('/admin/accounts/${a.id}/edit'),
              ),
              PopupMenuButton<AccountAction>(
                onSelected: (act) => _runAction(context, ref, a, act),
                itemBuilder: (context) => _menuItems(context, a),
              ),
            ]),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
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

  List<PopupMenuEntry<AccountAction>> _menuItems(
      BuildContext context, AdminAccount a) {
    final scheme = Theme.of(context).colorScheme;
    PopupMenuItem<AccountAction> item(AccountAction act, String key,
            {Color? color}) =>
        PopupMenuItem(
            value: act,
            height: 42,
            child: Text(context.tr(key),
                style: color == null ? null : TextStyle(color: color)));
    return [
      item(AccountAction.test, 'adminAccounts.test'),
      item(AccountAction.toggle,
          a.isActive ? 'adminAccounts.disable' : 'adminAccounts.enable'),
      if (a.isError) item(AccountAction.clearError, 'adminAccounts.clearError'),
      if (a.isRateLimited)
        item(AccountAction.clearRateLimit, 'adminAccounts.clearRateLimit'),
      if (a.hasRecoverableState)
        item(AccountAction.recoverState, 'adminAccounts.recoverState'),
      if (a.isOauthLike)
        item(AccountAction.refreshToken, 'adminAccounts.refreshToken'),
      if (a.hasQuotaLimit)
        item(AccountAction.resetQuota, 'adminAccounts.resetQuota'),
      if (a.supportsPrivacy)
        item(AccountAction.setPrivacy, 'adminAccounts.setPrivacy'),
      item(AccountAction.delete, 'adminAccounts.delete', color: scheme.error),
    ];
  }

  Future<void> _runAction(BuildContext context, WidgetRef ref, AdminAccount a,
      AccountAction act) async {
    final api = ref.read(adminAccountsApiProvider);
    try {
      switch (act) {
        case AccountAction.edit:
          context.push('/admin/accounts/${a.id}/edit');
          return;
        case AccountAction.test:
          await showAccountTestDialog(context, ref, a);
          return;
        case AccountAction.toggle:
          await api.setStatus(a.id, !a.isActive);
        case AccountAction.clearError:
          await api.clearError(a.id);
        case AccountAction.clearRateLimit:
          await api.clearRateLimit(a.id);
        case AccountAction.recoverState:
          await api.recoverState(a.id);
        case AccountAction.refreshToken:
          await api.refreshCredentials(a.id);
        case AccountAction.resetQuota:
          await api.resetQuota(a.id);
        case AccountAction.setPrivacy:
          await api.setPrivacy(a.id);
        case AccountAction.delete:
          final ok = await showConfirmDialog(
            context,
            title: context.tr('adminAccounts.delete'),
            message: context.tr('adminAccounts.deleteConfirm',
                params: {'name': a.name}),
            confirmLabel: context.tr('common.delete'),
            destructive: true,
          );
          if (!ok) return;
          await api.delete(a.id);
          ref.invalidate(adminAccountsControllerProvider);
          if (context.mounted) context.pop();
          return;
      }
      ref.invalidate(adminAccountDetailProvider(a.id));
      ref.invalidate(adminAccountsControllerProvider);
      if (context.mounted) showAppToast(context, context.tr('common.done'));
    } catch (e) {
      if (context.mounted) showAppToast(context, '$e', error: true);
    }
  }
}

class _Detail extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final a = account;
    String? fmtEpoch(int? e) => e == null || e == 0
        ? null
        : formatDateTime(
            DateTime.fromMillisecondsSinceEpoch(e * 1000).toLocal());
    final rows = <(String, String?)>[
      ('adminAccounts.platform', a.platform),
      ('adminAccounts.type', a.type),
      ('adminAccounts.concurrency', '${a.currentConcurrency}/${a.concurrency}'),
      ('adminAccounts.priority', '${a.priority}'),
      if (a.rateMultiplier != null)
        ('adminAccounts.rateMultiplier', '×${a.rateMultiplier!.toStringAsFixed(2)}'),
      ('adminAccounts.schedulable',
          context.tr(a.schedulable ? 'common.yes' : 'common.no')),
      if (a.groupNames.isNotEmpty)
        ('adminAccounts.groups', a.groupNames.join(', ')),
      if ((a.privacyMode ?? '').isNotEmpty)
        ('adminAccounts.privacy', a.privacyMode),
      if (a.proxyId != null) ('adminAccounts.proxy', '#${a.proxyId}'),
      if (a.windowCostLimit != null && a.windowCostLimit! > 0)
        ('adminAccounts.windowCostLimit', formatCost(a.windowCostLimit!)),
      if (a.maxSessions != null && a.maxSessions! > 0)
        ('adminAccounts.maxSessions', '${a.maxSessions}'),
      if (a.baseRpm != null && a.baseRpm! > 0)
        ('adminAccounts.baseRpm', '${a.baseRpm}'),
      if ((a.quotaLimit ?? 0) > 0)
        ('adminAccounts.quotaLimit', formatCost(a.quotaLimit!)),
      if ((a.quotaDailyLimit ?? 0) > 0)
        ('adminAccounts.quotaDaily', formatCost(a.quotaDailyLimit!)),
      if ((a.quotaWeeklyLimit ?? 0) > 0)
        ('adminAccounts.quotaWeekly', formatCost(a.quotaWeeklyLimit!)),
      if (a.isRateLimited)
        ('adminAccounts.rateLimitReset', a.rateLimitResetAt),
      if (a.isOverloaded) ('adminAccounts.overloadUntil', a.overloadUntil),
      if (a.isTempUnschedulable)
        ('adminAccounts.tempUnsched', a.tempUnschedulableUntil),
      if ((a.tempUnschedulableReason ?? '').isNotEmpty)
        ('adminAccounts.tempUnschedReason', a.tempUnschedulableReason),
      ('adminAccounts.expiresAt', fmtEpoch(a.expiresAt)),
      ('adminAccounts.lastUsed', a.lastUsedAt),
      ('adminAccounts.createdAt', a.createdAt),
      ('adminAccounts.updatedAt', a.updatedAt),
      if ((a.notes ?? '').isNotEmpty) ('adminAccounts.notes', a.notes),
    ];

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
          const SizedBox(height: 12),
          if (a.isError && (a.errorMessage ?? '').isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(a.errorMessage!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer)),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Column(
                children: [
                  for (final r in rows)
                    if (r.$2 != null && r.$2!.isNotEmpty)
                      _row(context, r.$1, r.$2!),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String labelKey, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(context.tr(labelKey),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
