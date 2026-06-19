import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../i18n/app_localizations.dart';
import '../../../../shared/format/formatters.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_retry.dart';
import '../../../../shared/widgets/responsive.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../../groups/providers/admin_groups_providers.dart';
import '../data/admin_subscriptions_api.dart';
import '../providers/admin_subscriptions_providers.dart';

enum _Action { progress, extend, resetQuota, revoke }

const _statuses = ['', 'active', 'expired', 'revoked'];

/// 订阅管理:用户订阅列表 + 状态/用户/分组筛选 + 分配 + 延长/重置配额/撤销 + 进度(对照 web)。
class SubscriptionsListPage extends ConsumerStatefulWidget {
  const SubscriptionsListPage({super.key});

  @override
  ConsumerState<SubscriptionsListPage> createState() =>
      _SubscriptionsListPageState();
}

class _SubscriptionsListPageState
    extends ConsumerState<SubscriptionsListPage> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
        ref.read(adminSubscriptionsControllerProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminSubscriptionsControllerProvider);
    final ctrl = ref.read(adminSubscriptionsControllerProvider.notifier);
    final filterBtn = IconButton.filledTonal(
      onPressed: () => _openFilters(context, state, ctrl),
      tooltip: context.tr('adminSubs.filters'),
      icon: const Icon(Icons.tune),
    );
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('adminSubs.title'))),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-admin-subs',
        onPressed: () => _assign(context),
        icon: const Icon(Icons.add),
        label: Text(context.tr('adminSubs.assign')),
      ),
      body: Column(
        children: [
          ResponsiveCenter(
            maxWidth: 1100,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
              child: Row(children: [
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final s in _statuses)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(s.isEmpty
                                  ? context.tr('adminSubs.allStatus')
                                  : context.tr('adminSubs.status_$s')),
                              selected: state.status == s,
                              onSelected: (_) => ctrl.setStatus(s),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                state.activeFilterCount > 0
                    ? Badge.count(
                        count: state.activeFilterCount, child: filterBtn)
                    : filterBtn,
              ]),
            ),
          ),
          Expanded(child: _body(context, state, ctrl)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, AdminSubscriptionsState state,
      AdminSubscriptionsController ctrl) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.items.isEmpty) {
      return ErrorRetryView(error: state.error!, onRetry: ctrl.refresh);
    }
    if (state.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: ctrl.refresh,
        child: ListView(children: [
          const SizedBox(height: 120),
          EmptyState(
              icon: Icons.card_membership_outlined,
              message: context.tr('adminSubs.empty')),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: ctrl.refresh,
      child: ResponsiveCenter(
        maxWidth: 1100,
        child: ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 24),
          itemCount: state.items.length + 1,
          itemBuilder: (context, i) {
            if (i == state.items.length) {
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
                    context
                        .tr('adminSubs.total', params: {'n': '${state.total}'}),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              );
            }
            return _SubCard(
              sub: state.items[i],
              onAction: (a) => _runAction(context, ctrl, state.items[i], a),
            );
          },
        ),
      ),
    );
  }

  Future<void> _runAction(BuildContext context,
      AdminSubscriptionsController ctrl, AdminSubscription s, _Action a) async {
    final api = ref.read(adminSubscriptionsApiProvider);
    switch (a) {
      case _Action.progress:
        _showProgress(context, s);
      case _Action.extend:
        final days = await _askDays(context);
        if (days == null) return;
        try {
          await api.extend(s.id, days);
          await ctrl.refresh();
          if (context.mounted) showAppToast(context, context.tr('common.done'));
        } catch (e) {
          if (context.mounted) showAppToast(context, '$e', error: true);
        }
      case _Action.resetQuota:
        final ok = await showConfirmDialog(
          context,
          title: context.tr('adminSubs.resetQuota'),
          message: context.tr('adminSubs.resetQuotaConfirm'),
          confirmLabel: context.tr('adminSubs.resetQuota'),
        );
        if (!ok) return;
        try {
          await api.resetQuota(s.id);
          await ctrl.refresh();
          if (context.mounted) showAppToast(context, context.tr('common.done'));
        } catch (e) {
          if (context.mounted) showAppToast(context, '$e', error: true);
        }
      case _Action.revoke:
        final ok = await showConfirmDialog(
          context,
          title: context.tr('adminSubs.revoke'),
          message: context.tr('adminSubs.revokeConfirm'),
          confirmLabel: context.tr('adminSubs.revoke'),
          destructive: true,
        );
        if (!ok) return;
        try {
          await api.revoke(s.id);
          await ctrl.refresh();
          if (context.mounted) showAppToast(context, context.tr('common.done'));
        } catch (e) {
          if (context.mounted) showAppToast(context, '$e', error: true);
        }
    }
  }

  Future<int?> _askDays(BuildContext context) async {
    final ctrl = TextEditingController(text: '30');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('adminSubs.extend')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: ctx.tr('adminSubs.days'),
            isDense: true,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.tr('common.cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.tr('common.confirm'))),
        ],
      ),
    );
    if (ok != true) return null;
    final d = int.tryParse(ctrl.text.trim());
    return (d != null && d > 0) ? d : null;
  }

  void _showProgress(BuildContext context, AdminSubscription s) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _ProgressSheet(subscriptionId: s.id, sub: s),
    );
  }

  Future<void> _openFilters(BuildContext context, AdminSubscriptionsState state,
      AdminSubscriptionsController ctrl) async {
    int? userId = state.userId;
    var userEmail = state.userEmail;
    int? groupId = state.groupId;
    final groups = (ref.read(adminGroupsFullProvider).value ?? const [])
        .where((g) => g.subscriptionType == 'subscription')
        .toList();

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(
              16, 0, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ctx.tr('adminSubs.fUser'),
                  style: Theme.of(ctx).textTheme.labelLarge),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await pickAdminUser(context, ref);
                  if (picked != null) {
                    setS(() {
                      userId = picked.$1;
                      userEmail = picked.$2;
                    });
                  }
                },
                icon: const Icon(Icons.person_search, size: 18),
                label: Text(userId == null
                    ? ctx.tr('adminSubs.allUsers')
                    : userEmail),
              ),
              if (userId != null)
                TextButton(
                  onPressed: () => setS(() {
                    userId = null;
                    userEmail = '';
                  }),
                  child: Text(ctx.tr('adminSubs.clearUser')),
                ),
              const SizedBox(height: 12),
              Text(ctx.tr('adminSubs.fGroup'),
                  style: Theme.of(ctx).textTheme.labelLarge),
              const SizedBox(height: 6),
              DropdownButtonFormField<int?>(
                initialValue: groupId,
                isExpanded: true,
                decoration: const InputDecoration(
                    isDense: true, border: OutlineInputBorder()),
                items: [
                  DropdownMenuItem(
                      value: null, child: Text(ctx.tr('adminSubs.allGroups'))),
                  for (final g in groups)
                    DropdownMenuItem(value: g.id, child: Text(g.name)),
                ],
                onChanged: (v) => setS(() => groupId = v),
              ),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      userId = null;
                      userEmail = '';
                      groupId = null;
                      Navigator.pop(ctx, true);
                    },
                    child: Text(ctx.tr('adminSubs.reset')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(ctx.tr('adminSubs.apply')),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
    if (ok == true) {
      ctrl.applyFilters(
          userId: userId, userEmail: userEmail, groupId: groupId);
    }
  }

  Future<void> _assign(BuildContext context) async {
    int? userId;
    var userEmail = '';
    int? groupId;
    final daysCtrl = TextEditingController(text: '30');
    final groups = (ref.read(adminGroupsFullProvider).value ?? const [])
        .where((g) =>
            g.subscriptionType == 'subscription' && g.status == 'active')
        .toList();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('adminSubs.assign')),
        content: SizedBox(
          width: 360,
          child: StatefulBuilder(
            builder: (ctx, setS) =>
                Column(mainAxisSize: MainAxisSize.min, children: [
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await pickAdminUser(context, ref);
                  if (picked != null) {
                    setS(() {
                      userId = picked.$1;
                      userEmail = picked.$2;
                    });
                  }
                },
                icon: const Icon(Icons.person_search, size: 18),
                label: Text(
                    userId == null ? ctx.tr('adminSubs.pickUser') : userEmail),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                initialValue: groupId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: ctx.tr('adminSubs.group'),
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  for (final g in groups)
                    DropdownMenuItem(
                        value: g.id,
                        child: Text('${g.name} · ${g.platform}',
                            overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setS(() => groupId = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: daysCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: ctx.tr('adminSubs.validityDays'),
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.tr('common.cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.tr('adminSubs.assign'))),
        ],
      ),
    );
    if (ok != true) return;
    if (userId == null || groupId == null) {
      if (context.mounted) {
        showAppToast(context, context.tr('adminSubs.errUserGroup'), error: true);
      }
      return;
    }
    final days = int.tryParse(daysCtrl.text.trim());
    try {
      await ref.read(adminSubscriptionsApiProvider).assign(
            userId: userId!,
            groupId: groupId!,
            validityDays: (days != null && days > 0) ? days : null,
          );
      await ref.read(adminSubscriptionsControllerProvider.notifier).refresh();
      if (context.mounted) showAppToast(context, context.tr('common.done'));
    } catch (e) {
      if (context.mounted) showAppToast(context, '$e', error: true);
    }
  }
}

/// 通用管理端用户搜索选择器(返回 (id, email))。
Future<(int, String)?> pickAdminUser(BuildContext context, WidgetRef ref) {
  final searchCtrl = TextEditingController();
  var results = <({int id, String email})>[];
  var loading = false;
  return showDialog<(int, String)>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(ctx.tr('adminSubs.pickUser')),
      content: SizedBox(
        width: 360,
        child: StatefulBuilder(
          builder: (ctx, setS) {
            Future<void> doSearch() async {
              setS(() => loading = true);
              try {
                results = await ref
                    .read(adminSubscriptionsApiProvider)
                    .searchUsers(searchCtrl.text.trim());
              } catch (_) {
                results = [];
              }
              setS(() => loading = false);
            }

            return Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: searchCtrl,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => doSearch(),
                decoration: InputDecoration(
                  hintText: ctx.tr('adminSubs.userEmailHint'),
                  isDense: true,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                      icon: const Icon(Icons.search), onPressed: doSearch),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 260,
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : results.isEmpty
                        ? Center(
                            child: Text(ctx.tr('adminSubs.noUsersFound'),
                                style: TextStyle(
                                    color: Theme.of(ctx)
                                        .colorScheme
                                        .onSurfaceVariant)))
                        : ListView.builder(
                            itemCount: results.length,
                            itemBuilder: (c, i) => ListTile(
                              dense: true,
                              title: Text(results[i].email,
                                  overflow: TextOverflow.ellipsis),
                              subtitle: Text('#${results[i].id}'),
                              onTap: () => Navigator.pop(
                                  ctx, (results[i].id, results[i].email)),
                            ),
                          ),
              ),
            ]);
          },
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.tr('common.cancel'))),
      ],
    ),
  );
}

class _SubCard extends StatelessWidget {
  const _SubCard({required this.sub, required this.onAction});
  final AdminSubscription sub;
  final ValueChanged<_Action> onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tone = switch (sub.status) {
      'active' => StatusTone.positive,
      'revoked' => StatusTone.danger,
      _ => StatusTone.neutral,
    };
    String fmt(String? raw) {
      if (raw == null || raw.isEmpty) return '-';
      final d = DateTime.tryParse(raw);
      return d == null ? raw : formatDate(d.toLocal());
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(sub.userEmail ?? '#${sub.userId}',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
              ),
              StatusPill(
                  label: context.tr('adminSubs.status_${sub.status}'),
                  tone: tone,
                  dense: true),
              PopupMenuButton<_Action>(
                icon: const Icon(Icons.more_vert, size: 20),
                padding: EdgeInsets.zero,
                onSelected: onAction,
                itemBuilder: (context) => [
                  PopupMenuItem(
                      value: _Action.progress,
                      height: 40,
                      child: Text(context.tr('adminSubs.viewProgress'))),
                  PopupMenuItem(
                      value: _Action.extend,
                      height: 40,
                      child: Text(context.tr('adminSubs.extend'))),
                  PopupMenuItem(
                      value: _Action.resetQuota,
                      height: 40,
                      child: Text(context.tr('adminSubs.resetQuota'))),
                  PopupMenuItem(
                      value: _Action.revoke,
                      height: 40,
                      child: Text(context.tr('adminSubs.revoke'),
                          style: TextStyle(color: scheme.error))),
                ],
              ),
            ]),
            Text(
              '${sub.groupName ?? '#${sub.groupId}'}'
              '${sub.groupPlatform != null ? ' · ${sub.groupPlatform}' : ''}'
              '  ·  ${context.tr('adminSubs.expiresAt')} ${fmt(sub.expiresAt)}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            _bar(context, context.tr('adminSubs.daily'), sub.dailyUsageUsd,
                sub.dailyLimitUsd),
            _bar(context, context.tr('adminSubs.weekly'), sub.weeklyUsageUsd,
                sub.weeklyLimitUsd),
            _bar(context, context.tr('adminSubs.monthly'), sub.monthlyUsageUsd,
                sub.monthlyLimitUsd),
          ],
        ),
      ),
    );
  }

  Widget _bar(BuildContext context, String label, num used, num? limit) {
    final scheme = Theme.of(context).colorScheme;
    final hasLimit = limit != null && limit > 0;
    final pct = hasLimit ? (used / limit).clamp(0.0, 1.0).toDouble() : 0.0;
    final color = pct >= 0.9
        ? scheme.error
        : pct >= 0.7
            ? const Color(0xFFB7791F)
            : scheme.primary;
    return Padding(
      padding: const EdgeInsets.only(top: 3, right: 8),
      child: Row(children: [
        SizedBox(
            width: 36,
            child: Text(label,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: hasLimit ? pct : 0,
              minHeight: 6,
              backgroundColor: scheme.surfaceContainerHighest,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          hasLimit
              ? '${formatCost(used.toDouble())}/${formatCost(limit.toDouble())}'
              : formatCost(used.toDouble()),
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ]),
    );
  }
}

class _ProgressSheet extends ConsumerWidget {
  const _ProgressSheet({required this.subscriptionId, required this.sub});
  final int subscriptionId;
  final AdminSubscription sub;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminSubscriptionProgressProvider(subscriptionId));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: async.when(
        loading: () => const SizedBox(
            height: 200, child: Center(child: CircularProgressIndicator())),
        error: (e, _) => SizedBox(
            height: 160,
            child: Center(child: Text('$e'))),
        data: (p) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(sub.userEmail ?? '#${sub.userId}',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            if (p.daysRemaining != null)
              Text(
                  context.tr('adminSubs.daysRemaining',
                      params: {'n': '${p.daysRemaining}'}),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            _win(context, context.tr('adminSubs.daily'), p.daily),
            _win(context, context.tr('adminSubs.weekly'), p.weekly),
            _win(context, context.tr('adminSubs.monthly'), p.monthly),
          ],
        ),
      ),
    );
  }

  Widget _win(BuildContext context, String label, SubscriptionWindow? w) {
    if (w == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final hasLimit = w.limit != null && w.limit! > 0;
    final pct =
        hasLimit ? (w.used / w.limit!).clamp(0.0, 1.0).toDouble() : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
                child: Text(label,
                    style: Theme.of(context).textTheme.labelLarge)),
            Text(hasLimit
                ? '${formatCost(w.used.toDouble())} / ${formatCost(w.limit!.toDouble())}'
                : formatCost(w.used.toDouble())),
          ]),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: hasLimit ? pct : 0,
              minHeight: 8,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
          if (w.resetInSeconds != null) ...[
            const SizedBox(height: 2),
            Text(
              context.tr('adminSubs.resetIn',
                  params: {'t': _dur(w.resetInSeconds!)}),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }

  String _dur(int seconds) {
    if (seconds <= 0) return '0m';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h >= 24) return '${h ~/ 24}d ${h % 24}h';
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}
