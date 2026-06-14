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

/// 账号池(管理端底部导航分支):搜索 + 平台/状态筛选 + 分页列表 + 逐项操作。
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

    return Column(
      children: [
        _FilterBar(
          searchCtrl: _searchCtrl,
          status: state.status,
          platform: state.platform,
          onSearch: ctrl.setSearch,
          onStatus: ctrl.setStatus,
          onPlatform: ctrl.setPlatform,
        ),
        Expanded(child: _body(context, state, ctrl)),
      ],
    );
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
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
          itemCount: state.items.length + 1,
          itemBuilder: (context, i) {
            if (i == state.items.length) {
              return _Footer(state: state);
            }
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
      AdminAccount a, _AccountAction act) async {
    final api = ref.read(adminAccountsApiProvider);
    try {
      switch (act) {
        case _AccountAction.toggle:
          await api.setStatus(a.id, !a.isActive);
          await ctrl.refresh();
        case _AccountAction.test:
          showAppToast(context, context.tr('adminAccounts.testing'));
          final r = await api.test(a.id);
          if (context.mounted) {
            showAppToast(
              context,
              r.latencyMs != null ? '${r.message} (${r.latencyMs}ms)' : r.message,
              error: !r.success,
            );
          }
        case _AccountAction.clearError:
          await api.clearError(a.id);
          await ctrl.refresh();
        case _AccountAction.clearRateLimit:
          await api.clearRateLimit(a.id);
          await ctrl.refresh();
        case _AccountAction.refresh:
          showAppToast(context, context.tr('adminAccounts.refreshing'));
          await api.refreshCredentials(a.id);
          await ctrl.refresh();
        case _AccountAction.delete:
          final ok = await showConfirmDialog(
            context,
            title: context.tr('adminAccounts.delete'),
            message: context.tr('adminAccounts.deleteConfirm',
                params: {'name': a.name}),
            confirmLabel: context.tr('common.delete'),
            destructive: true,
          );
          if (ok) {
            await api.delete(a.id);
            await ctrl.refresh();
          }
      }
    } catch (e) {
      if (context.mounted) showAppToast(context, '$e', error: true);
    }
  }
}

enum _AccountAction { toggle, test, clearError, clearRateLimit, refresh, delete }

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.searchCtrl,
    required this.status,
    required this.platform,
    required this.onSearch,
    required this.onStatus,
    required this.onPlatform,
  });

  final TextEditingController searchCtrl;
  final String status;
  final String platform;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onStatus;
  final ValueChanged<String> onPlatform;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: ResponsiveCenter(
        maxWidth: 1100,
        child: Column(
          children: [
            TextField(
              controller: searchCtrl,
              onSubmitted: onSearch,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: context.tr('adminAccounts.searchHint'),
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _Dropdown(
                    value: status,
                    label: context.tr('adminAccounts.status'),
                    items: const {
                      '': 'adminAccounts.statusAll',
                      'active': 'adminAccounts.statusActive',
                      'inactive': 'adminAccounts.statusInactive',
                      'error': 'adminAccounts.statusError',
                    },
                    onChanged: onStatus,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Dropdown(
                    value: platform,
                    label: context.tr('adminAccounts.platform'),
                    items: const {
                      '': 'adminAccounts.platformAll',
                      'anthropic': 'adminAccounts.platformAnthropic',
                      'openai': 'adminAccounts.platformOpenai',
                      'gemini': 'adminAccounts.platformGemini',
                      'antigravity': 'adminAccounts.platformAntigravity',
                    },
                    onChanged: onPlatform,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Dropdown extends StatelessWidget {
  const _Dropdown({
    required this.value,
    required this.label,
    required this.items,
    required this.onChanged,
  });

  final String value;
  final String label;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final e in items.entries)
          DropdownMenuItem(value: e.key, child: Text(context.tr(e.value))),
      ],
      onChanged: (v) => onChanged(v ?? ''),
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
      padding: const EdgeInsets.all(16),
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
  final ValueChanged<_AccountAction> onAction;

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
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
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
                  PopupMenuButton<_AccountAction>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    onSelected: onAction,
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: _AccountAction.toggle,
                        child: Text(context.tr(account.isActive
                            ? 'adminAccounts.disable'
                            : 'adminAccounts.enable')),
                      ),
                      PopupMenuItem(
                        value: _AccountAction.test,
                        child: Text(context.tr('adminAccounts.test')),
                      ),
                      if (account.isError)
                        PopupMenuItem(
                          value: _AccountAction.clearError,
                          child: Text(context.tr('adminAccounts.clearError')),
                        ),
                      PopupMenuItem(
                        value: _AccountAction.clearRateLimit,
                        child: Text(context.tr('adminAccounts.clearRateLimit')),
                      ),
                      PopupMenuItem(
                        value: _AccountAction.refresh,
                        child: Text(context.tr('adminAccounts.refresh')),
                      ),
                      PopupMenuItem(
                        value: _AccountAction.delete,
                        child: Text(
                          context.tr('adminAccounts.delete'),
                          style: TextStyle(color: scheme.error),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _chip(context, account.platform),
                  _chip(context, account.type),
                  for (final g in account.groupNames) _chip(context, g),
                ],
              ),
              if (account.isError &&
                  (account.errorMessage ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  account.errorMessage!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.error),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  _meta(context, Icons.bolt_outlined,
                      '${account.currentConcurrency}/${account.concurrency}'),
                  const SizedBox(width: 14),
                  _meta(context, Icons.low_priority_outlined,
                      '${account.priority}'),
                  if (account.rateMultiplier != null) ...[
                    const SizedBox(width: 14),
                    _meta(context, Icons.percent,
                        '×${account.rateMultiplier!.toStringAsFixed(2)}'),
                  ],
                  const Spacer(),
                  Text(
                    formatCost(todayCost ?? 0),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String label) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }

  Widget _meta(BuildContext context, IconData icon, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: scheme.onSurfaceVariant),
        const SizedBox(width: 3),
        Text(text,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant)),
      ],
    );
  }
}
