import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../i18n/app_localizations.dart';
import '../../../../shared/format/formatters.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_retry.dart';
import '../../../../shared/widgets/responsive.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../../accounts/providers/admin_accounts_providers.dart';
import '../data/admin_redeem_api.dart';
import '../providers/admin_redeem_providers.dart';

enum _CodeAction { copy, expire, delete }

const _types = ['balance', 'concurrency', 'subscription', 'invitation'];

/// 兑换码管理:统计 + 列表 + 类型/状态筛选 + 批量生成 + 作废/删除。
class RedeemListPage extends ConsumerStatefulWidget {
  const RedeemListPage({super.key});

  @override
  ConsumerState<RedeemListPage> createState() => _RedeemListPageState();
}

class _RedeemListPageState extends ConsumerState<RedeemListPage> {
  final _scroll = ScrollController();
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
        ref.read(adminRedeemControllerProvider.notifier).loadMore();
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
    final state = ref.watch(adminRedeemControllerProvider);
    final ctrl = ref.read(adminRedeemControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('adminRedeem.title'))),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-admin-redeem',
        onPressed: () => _generate(context),
        icon: const Icon(Icons.add),
        label: Text(context.tr('adminRedeem.generate')),
      ),
      body: Column(
        children: [
          _searchBar(context, state, ctrl),
          Expanded(child: _body(context, state, ctrl)),
        ],
      ),
    );
  }

  Widget _searchBar(BuildContext context, AdminRedeemState state,
      AdminRedeemController ctrl) {
    final filterBtn = IconButton.filledTonal(
      onPressed: () => _openFilters(context, state, ctrl),
      tooltip: context.tr('adminRedeem.filters'),
      icon: const Icon(Icons.tune),
    );
    return ResponsiveCenter(
      maxWidth: 1100,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
        child: SizedBox(
          height: 52,
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                onSubmitted: ctrl.setSearch,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: context.tr('adminRedeem.searchHint'),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 6),
            state.activeFilterCount > 0
                ? Badge.count(count: state.activeFilterCount, child: filterBtn)
                : filterBtn,
          ]),
        ),
      ),
    );
  }

  Future<void> _openFilters(BuildContext context, AdminRedeemState state,
      AdminRedeemController ctrl) async {
    var type = state.type;
    var status = state.status;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(
              16, 0, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ctx.tr('adminRedeem.type'),
                  style: Theme.of(ctx).textTheme.labelLarge),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4, children: [
                ChoiceChip(
                  label: Text(ctx.tr('adminRedeem.all')),
                  selected: type.isEmpty,
                  onSelected: (_) => setS(() => type = ''),
                ),
                for (final t in _types)
                  ChoiceChip(
                    label: Text(ctx.tr('adminRedeem.type_$t')),
                    selected: type == t,
                    onSelected: (_) => setS(() => type = t),
                  ),
              ]),
              const SizedBox(height: 14),
              Text(ctx.tr('adminRedeem.status'),
                  style: Theme.of(ctx).textTheme.labelLarge),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4, children: [
                for (final s in ['', 'unused', 'used', 'expired', 'disabled'])
                  ChoiceChip(
                    label: Text(s.isEmpty
                        ? ctx.tr('adminRedeem.all')
                        : ctx.tr('adminRedeem.status_$s')),
                    selected: status == s,
                    onSelected: (_) => setS(() => status = s),
                  ),
              ]),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      type = '';
                      status = '';
                      Navigator.pop(ctx, true);
                    },
                    child: Text(ctx.tr('adminRedeem.reset')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(ctx.tr('adminRedeem.apply')),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
    if (ok == true) ctrl.applyFilters(type: type, status: status);
  }

  Widget _body(BuildContext context, AdminRedeemState state,
      AdminRedeemController ctrl) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.items.isEmpty) {
      return ErrorRetryView(error: state.error!, onRetry: ctrl.refresh);
    }
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(adminRedeemStatsProvider);
        await ctrl.refresh();
      },
      child: ResponsiveCenter(
        maxWidth: 1100,
        child: ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(10, 2, 10, 24),
          itemCount: state.items.length + 2,
          itemBuilder: (context, i) {
            if (i == 0) return _statsHeader(context);
            final idx = i - 1;
            if (idx == state.items.length) {
              if (state.loadingMore) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (state.items.isEmpty) {
                return EmptyState(
                  icon: Icons.confirmation_number_outlined,
                  message: context.tr('adminRedeem.empty'),
                );
              }
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Center(
                  child: Text(
                    context.tr('adminRedeem.total', params: {'n': '${state.total}'}),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              );
            }
            return _CodeCard(
              code: state.items[idx],
              onAction: (a) => _runAction(context, ctrl, state.items[idx], a),
            );
          },
        ),
      ),
    );
  }

  Widget _statsHeader(BuildContext context) {
    final async = ref.watch(adminRedeemStatsProvider);
    return async.maybeWhen(
      data: (s) => Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _stat(context, '${s.totalCodes}', 'adminRedeem.statTotal'),
              _stat(context, '${s.usedCodes}', 'adminRedeem.statUsed'),
              _stat(context, '${s.expiredCodes}', 'adminRedeem.statExpired'),
            ],
          ),
        ),
      ),
      orElse: () => const SizedBox(height: 8),
    );
  }

  Widget _stat(BuildContext context, String value, String labelKey) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(value,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w700)),
      Text(context.tr(labelKey),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
    ]);
  }

  Future<void> _runAction(BuildContext context, AdminRedeemController ctrl,
      RedeemCode c, _CodeAction a) async {
    final api = ref.read(adminRedeemApiProvider);
    try {
      switch (a) {
        case _CodeAction.copy:
          await Clipboard.setData(ClipboardData(text: c.code));
          if (context.mounted) {
            showAppToast(context, context.tr('adminRedeem.copied'));
          }
          return;
        case _CodeAction.expire:
          await api.expire(c.id);
        case _CodeAction.delete:
          final ok = await showConfirmDialog(
            context,
            title: context.tr('adminRedeem.delete'),
            message: context.tr('adminRedeem.deleteConfirm'),
            confirmLabel: context.tr('common.delete'),
            destructive: true,
          );
          if (!ok) return;
          await api.delete(c.id);
      }
      ref.invalidate(adminRedeemStatsProvider);
      await ctrl.refresh();
      if (context.mounted) showAppToast(context, context.tr('common.done'));
    } catch (e) {
      if (context.mounted) showAppToast(context, '$e', error: true);
    }
  }

  Future<void> _generate(BuildContext context) async {
    final countCtrl = TextEditingController(text: '1');
    final valueCtrl = TextEditingController();
    final validityCtrl = TextEditingController();
    final expiresCtrl = TextEditingController();
    var type = 'balance';
    int? groupId;
    final groups = ref.read(adminGroupsAllProvider).value ?? const [];

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('adminRedeem.generate')),
        content: SizedBox(
          width: 340,
          child: StatefulBuilder(
            builder: (ctx, setS) => SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(spacing: 6, runSpacing: 4, children: [
                    for (final t in _types)
                      ChoiceChip(
                        label: Text(ctx.tr('adminRedeem.type_$t')),
                        selected: type == t,
                        onSelected: (_) => setS(() => type = t),
                      ),
                  ]),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: countCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: ctx.tr('adminRedeem.count'),
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: valueCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: ctx.tr('adminRedeem.value'),
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ]),
                if (type == 'subscription') ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: groupId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: ctx.tr('adminRedeem.group'),
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      for (final g in groups)
                        DropdownMenuItem(value: g.id, child: Text(g.name)),
                    ],
                    onChanged: (v) => setS(() => groupId = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: validityCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: ctx.tr('adminRedeem.validityDays'),
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: expiresCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: ctx.tr('adminRedeem.expiresInDays'),
                    helperText: ctx.tr('adminRedeem.expiresInHint'),
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ]),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.tr('common.cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.tr('adminRedeem.generate'))),
        ],
      ),
    );
    if (ok != true) return;
    final count = int.tryParse(countCtrl.text.trim()) ?? 0;
    final value = num.tryParse(valueCtrl.text.trim());
    if (count <= 0 || value == null) {
      if (context.mounted) {
        showAppToast(context, context.tr('adminRedeem.invalidInput'),
            error: true);
      }
      return;
    }
    try {
      final codes = await ref.read(adminRedeemApiProvider).generate(
            count: count,
            type: type,
            value: value,
            groupId: groupId,
            validityDays: int.tryParse(validityCtrl.text.trim()),
            expiresInDays: int.tryParse(expiresCtrl.text.trim()),
          );
      ref.invalidate(adminRedeemStatsProvider);
      await ref.read(adminRedeemControllerProvider.notifier).refresh();
      if (context.mounted) {
        showAppToast(context,
            context.tr('adminRedeem.generated', params: {'n': '${codes.length}'}));
      }
    } catch (e) {
      if (context.mounted) showAppToast(context, '$e', error: true);
    }
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.code, required this.onAction});
  final RedeemCode code;
  final ValueChanged<_CodeAction> onAction;

  StatusTone get _tone => switch (code.status) {
        'unused' || 'active' => StatusTone.positive,
        'used' => StatusTone.neutral,
        'expired' || 'disabled' => StatusTone.warning,
        _ => StatusTone.neutral,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(code.code,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600, fontFamily: 'monospace'),
                    overflow: TextOverflow.ellipsis),
              ),
              StatusPill(
                  label: context.tr('adminRedeem.status_${code.status}'),
                  tone: _tone,
                  dense: true),
              PopupMenuButton<_CodeAction>(
                icon: const Icon(Icons.more_vert, size: 20),
                padding: EdgeInsets.zero,
                onSelected: onAction,
                itemBuilder: (context) => [
                  PopupMenuItem(
                      value: _CodeAction.copy,
                      height: 40,
                      child: Text(context.tr('adminRedeem.copy'))),
                  if (!code.isUsed && code.status != 'expired')
                    PopupMenuItem(
                        value: _CodeAction.expire,
                        height: 40,
                        child: Text(context.tr('adminRedeem.expire'))),
                  PopupMenuItem(
                      value: _CodeAction.delete,
                      height: 40,
                      child: Text(context.tr('adminRedeem.delete'),
                          style: TextStyle(color: scheme.error))),
                ],
              ),
            ]),
            DefaultTextStyle.merge(
              style: Theme.of(context)
                  .textTheme
                  .bodySmall!
                  .copyWith(color: scheme.onSurfaceVariant),
              child: Row(children: [
                Text(context.tr('adminRedeem.type_${code.type}')),
                _dot(context),
                Text(code.type == 'balance'
                    ? formatCost(code.value.toDouble())
                    : '${code.value}'),
                if (code.expiresAt != null) ...[
                  _dot(context),
                  Flexible(
                      child: Text('${context.tr('adminRedeem.expiresAt')} ${code.expiresAt}',
                          overflow: TextOverflow.ellipsis)),
                ],
                const SizedBox(width: 4),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dot(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text('·',
            style: TextStyle(color: Theme.of(context).colorScheme.outline)),
      );
}
