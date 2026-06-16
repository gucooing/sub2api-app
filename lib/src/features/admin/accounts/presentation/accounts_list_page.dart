import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../i18n/app_localizations.dart';
import '../../../../shared/format/formatters.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_retry.dart';
import '../../../../shared/widgets/responsive.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../data/admin_accounts_api.dart';
import '../providers/admin_accounts_providers.dart';
import 'account_filter_sheet.dart';
import 'account_test_dialog.dart';

/// 账号池(管理端底部导航分支):紧凑列表 + 搜索 + 弹层筛选 + 新增 + 逐项操作。
class AccountsListPage extends ConsumerStatefulWidget {
  const AccountsListPage({super.key});

  @override
  ConsumerState<AccountsListPage> createState() => _AccountsListPageState();
}

class _AccountsListPageState extends ConsumerState<AccountsListPage> {
  final _scroll = ScrollController();
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
        ref.read(adminAccountsControllerProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminAccountsControllerProvider);
    final ctrl = ref.read(adminAccountsControllerProvider.notifier);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab-admin-accounts',
        onPressed: () => context.push('/admin/accounts/new'),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          _SearchBar(
            controller: _searchCtrl,
            filterCount: state.activeFilterCount,
            onSearch: ctrl.setSearch,
            onOpenFilters: () => _openFilters(context, state, ctrl),
          ),
          Expanded(child: _body(context, state, ctrl)),
        ],
      ),
    );
  }

  Future<void> _openFilters(BuildContext context, AdminAccountsState state,
      AdminAccountsController ctrl) async {
    final result = await showAccountFilterSheet(
      context,
      ref,
      initial: AccountFilterValues(
        status: state.status,
        platform: state.platform,
        type: state.type,
        group: state.group,
        privacyMode: state.privacyMode,
      ),
    );
    if (result != null) {
      ctrl.applyFilters(
        status: result.status,
        platform: result.platform,
        type: result.type,
        group: result.group,
        privacyMode: result.privacyMode,
      );
    }
  }

  Widget _body(BuildContext context, AdminAccountsState state,
      AdminAccountsController ctrl) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.items.isEmpty) {
      return ErrorRetryView(error: state.error!, onRetry: ctrl.refresh);
    }
    if (state.items.isEmpty) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        message: context.tr('adminAccounts.empty'),
      );
    }
    return RefreshIndicator(
      onRefresh: ctrl.refresh,
      child: ResponsiveCenter(
        maxWidth: 1100,
        child: ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(10, 2, 10, 24),
          itemCount: state.items.length + 1,
          itemBuilder: (context, i) {
            if (i == state.items.length) return _Footer(state: state);
            final a = state.items[i];
            return _AccountCard(
              account: a,
              todayCost: state.todayCost[a.id],
              onTap: () => context.push('/admin/accounts/${a.id}'),
              onAction: (act) => _runAction(context, ctrl, a, act),
            );
          },
        ),
      ),
    );
  }

  Future<void> _runAction(BuildContext context, AdminAccountsController ctrl,
      AdminAccount a, AccountAction act) async {
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
          showAppToast(context, context.tr('adminAccounts.refreshing'));
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
      }
      await ctrl.refresh();
      if (context.mounted) showAppToast(context, context.tr('common.done'));
    } catch (e) {
      if (context.mounted) showAppToast(context, '$e', error: true);
    }
  }
}

/// 逐项操作(按账号类型/状态出显)。
enum AccountAction {
  edit,
  test,
  toggle,
  clearError,
  clearRateLimit,
  recoverState,
  refreshToken,
  resetQuota,
  setPrivacy,
  delete,
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.filterCount,
    required this.onSearch,
    required this.onOpenFilters,
  });

  final TextEditingController controller;
  final int filterCount;
  final ValueChanged<String> onSearch;
  final VoidCallback onOpenFilters;

  @override
  Widget build(BuildContext context) {
    final filterBtn = IconButton.filledTonal(
      onPressed: onOpenFilters,
      tooltip: context.tr('adminAccounts.filters'),
      icon: const Icon(Icons.tune),
    );
    return ResponsiveCenter(
      maxWidth: 1100,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
        child: SizedBox(
          height: 52,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  onSubmitted: onSearch,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: context.tr('adminAccounts.searchHint'),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              filterCount > 0
                  ? Badge.count(count: filterCount, child: filterBtn)
                  : filterBtn,
            ],
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.state});
  final AdminAccountsState state;

  @override
  Widget build(BuildContext context) {
    if (state.loadingMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Center(
        child: Text(
          context.tr('adminAccounts.total', params: {'n': '${state.total}'}),
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

/// 紧凑账号卡:名称 + 类型/平台 + 容量 + 状态 + 调度,信息密度优先。
class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.account,
    required this.todayCost,
    required this.onTap,
    required this.onAction,
  });

  final AdminAccount account;
  final double? todayCost;
  final VoidCallback onTap;
  final ValueChanged<AccountAction> onAction;

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
    final scheme = Theme.of(context).colorScheme;
    final schedTone = !account.schedulable
        ? StatusTone.neutral
        : account.isRateLimited
            ? StatusTone.warning
            : account.isTempUnschedulable
                ? StatusTone.warning
                : StatusTone.positive;
    final schedKey = !account.schedulable
        ? 'adminAccounts.schedOff'
        : account.isRateLimited
            ? 'adminAccounts.status.rateLimited'
            : account.isTempUnschedulable
                ? 'adminAccounts.status.tempUnschedulable'
                : 'adminAccounts.schedOn';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _badge(context, account.platform, scheme.primaryContainer,
                      scheme.onPrimaryContainer),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      account.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  StatusPill(
                      label: context.tr(_statusKey()), tone: _tone, dense: true),
                  PopupMenuButton<AccountAction>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    padding: EdgeInsets.zero,
                    onSelected: onAction,
                    itemBuilder: (context) => _menuItems(context),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              DefaultTextStyle.merge(
                style: Theme.of(context)
                    .textTheme
                    .bodySmall!
                    .copyWith(color: scheme.onSurfaceVariant),
                child: Row(
                  children: [
                    Text(account.type),
                    _dot(context),
                    Icon(Icons.bolt_outlined, size: 13, color: scheme.onSurfaceVariant),
                    Text(' ${account.currentConcurrency}/${account.concurrency}'),
                    _dot(context),
                    _MiniPill(label: context.tr(schedKey), tone: schedTone),
                    const Spacer(),
                    if (account.rateMultiplier != null) ...[
                      Text('×${account.rateMultiplier!.toStringAsFixed(2)}'),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      formatCost(todayCost ?? 0),
                      style: TextStyle(
                          color: scheme.primary, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<PopupMenuEntry<AccountAction>> _menuItems(BuildContext context) {
    PopupMenuItem<AccountAction> item(AccountAction a, String key,
            {Color? color}) =>
        PopupMenuItem(
          value: a,
          height: 40,
          child: Text(context.tr(key),
              style: color == null ? null : TextStyle(color: color)),
        );
    final scheme = Theme.of(context).colorScheme;
    return [
      item(AccountAction.edit, 'common.edit'),
      item(AccountAction.test, 'adminAccounts.test'),
      item(AccountAction.toggle,
          account.isActive ? 'adminAccounts.disable' : 'adminAccounts.enable'),
      if (account.isError) item(AccountAction.clearError, 'adminAccounts.clearError'),
      if (account.isRateLimited)
        item(AccountAction.clearRateLimit, 'adminAccounts.clearRateLimit'),
      if (account.hasRecoverableState)
        item(AccountAction.recoverState, 'adminAccounts.recoverState'),
      if (account.isOauthLike)
        item(AccountAction.refreshToken, 'adminAccounts.refreshToken'),
      if (account.hasQuotaLimit)
        item(AccountAction.resetQuota, 'adminAccounts.resetQuota'),
      if (account.supportsPrivacy)
        item(AccountAction.setPrivacy, 'adminAccounts.setPrivacy'),
      item(AccountAction.delete, 'adminAccounts.delete', color: scheme.error),
    ];
  }

  Widget _dot(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text('·',
            style: TextStyle(color: Theme.of(context).colorScheme.outline)),
      );

  Widget _badge(BuildContext context, String text, Color bg, Color fg) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: fg, fontWeight: FontWeight.w600)),
      );
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({required this.label, required this.tone});
  final String label;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (tone) {
      StatusTone.positive => const Color(0xFF4ADE80),
      StatusTone.warning => const Color(0xFFB7791F),
      StatusTone.danger => scheme.error,
      _ => scheme.onSurfaceVariant,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: color)),
    );
  }
}
