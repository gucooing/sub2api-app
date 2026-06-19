import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../i18n/app_localizations.dart';
import '../../../../shared/format/formatters.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_retry.dart';
import '../../../../shared/widgets/responsive.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../../orders/presentation/orders_tab.dart'
    show orderStatusTone, orderStatusLabel, paymentMethodLabel;
import '../data/admin_affiliates_api.dart';
import '../providers/admin_affiliates_providers.dart';

/// 邀请返利记录 Tab(邀请/返利/转账三类共用,按 type 渲染)。
class AffiliateRecordsTab extends ConsumerStatefulWidget {
  const AffiliateRecordsTab({super.key, required this.type});

  final AffiliateRecordType type;

  @override
  ConsumerState<AffiliateRecordsTab> createState() =>
      _AffiliateRecordsTabState();
}

class _AffiliateRecordsTabState extends ConsumerState<AffiliateRecordsTab>
    with AutomaticKeepAliveClientMixin {
  final _scroll = ScrollController();
  final _searchCtrl = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  NotifierProvider<AffiliateRecordsController, AffiliateRecordsState>
      get _provider => switch (widget.type) {
            AffiliateRecordType.invites => adminAffiliateInvitesProvider,
            AffiliateRecordType.rebates => adminAffiliateRebatesProvider,
            AffiliateRecordType.transfers => adminAffiliateTransfersProvider,
          };

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
        ref.read(_provider.notifier).loadMore();
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
    super.build(context);
    final state = ref.watch(_provider);
    final ctrl = ref.read(_provider.notifier);
    final hasFilters = state.startAt.isNotEmpty || state.endAt.isNotEmpty;
    return Column(
      children: [
        ResponsiveCenter(
          maxWidth: 1100,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onSubmitted: ctrl.setSearch,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: context.tr('adminAffiliates.searchHint'),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Badge(
                  isLabelVisible: hasFilters,
                  child: IconButton.filledTonal(
                    onPressed: () => _showFilterSheet(context, state, ctrl),
                    icon: const Icon(Icons.tune),
                    tooltip: context.tr('adminAffiliates.filterSort'),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(child: _body(context, state, ctrl)),
      ],
    );
  }

  Widget _body(BuildContext context, AffiliateRecordsState state,
      AffiliateRecordsController ctrl) {
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
              icon: Icons.people_alt_outlined,
              message: context.tr('adminAffiliates.empty')),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: ctrl.refresh,
      child: ResponsiveCenter(
        maxWidth: 1100,
        child: ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 24),
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
                    context.tr('adminAffiliates.total',
                        params: {'n': '${state.total}'}),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              );
            }
            final item = state.items[i];
            return switch (widget.type) {
              AffiliateRecordType.invites =>
                _inviteCard(context, item as AffiliateInviteRecord),
              AffiliateRecordType.rebates =>
                _rebateCard(context, item as AffiliateRebateRecord),
              AffiliateRecordType.transfers =>
                _transferCard(context, item as AffiliateTransferRecord),
            };
          },
        ),
      ),
    );
  }

  // ---------- 卡片 ----------

  Widget _inviteCard(BuildContext context, AffiliateInviteRecord r) {
    final scheme = Theme.of(context).colorScheme;
    final muted = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: scheme.onSurfaceVariant);
    return _cardShell(
      context,
      children: [
        Row(children: [
          Expanded(
            child: _userRef(context, r.inviterId, r.inviterEmail,
                r.inviterUsername, true),
          ),
          Icon(Icons.arrow_forward, size: 16, color: scheme.onSurfaceVariant),
          Expanded(
            child: _userRef(context, r.inviteeId, r.inviteeEmail,
                r.inviteeUsername, true,
                alignEnd: true),
          ),
        ]),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 2, children: [
          if (r.affCode.isNotEmpty)
            Text(r.affCode,
                style: muted?.copyWith(fontFamily: 'monospace')),
          Text('·', style: muted),
          Text(
              '${context.tr('adminAffiliates.totalRebate')} \$${r.totalRebate.toStringAsFixed(2)}',
              style: TextStyle(
                  color: scheme.tertiary, fontWeight: FontWeight.w600)),
          Text('·', style: muted),
          Text(_fmt(r.createdAt), style: muted),
        ]),
      ],
    );
  }

  Widget _rebateCard(BuildContext context, AffiliateRebateRecord r) {
    final scheme = Theme.of(context).colorScheme;
    final muted = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: scheme.onSurfaceVariant);
    return _cardShell(
      context,
      children: [
        Row(children: [
          Text('#${r.orderId}',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(r.outTradeNo,
                style: muted, overflow: TextOverflow.ellipsis),
          ),
          StatusPill(
              label: orderStatusLabel(context, r.orderStatus),
              tone: orderStatusTone(r.orderStatus),
              dense: true),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(
            child: _userRef(context, r.inviterId, r.inviterEmail,
                r.inviterUsername, true),
          ),
          Icon(Icons.arrow_forward, size: 16, color: scheme.onSurfaceVariant),
          Expanded(
            child: _userRef(context, r.inviteeId, r.inviteeEmail,
                r.inviteeUsername, true,
                alignEnd: true),
          ),
        ]),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 2, children: [
          Text(
              '${context.tr('adminAffiliates.orderAmount')} \$${r.orderAmount.toStringAsFixed(2)}',
              style: muted),
          Text('·', style: muted),
          Text(
              '${context.tr('adminAffiliates.payAmount')} ¥${r.payAmount.toStringAsFixed(2)}',
              style: muted),
          Text('·', style: muted),
          Text(
              '${context.tr('adminAffiliates.rebateAmount')} \$${r.rebateAmount.toStringAsFixed(2)}',
              style: TextStyle(
                  color: scheme.tertiary, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 2),
        Wrap(spacing: 8, children: [
          Text(paymentMethodLabel(context, r.paymentType), style: muted),
          Text('·', style: muted),
          Text(_fmt(r.createdAt), style: muted),
        ]),
      ],
    );
  }

  Widget _transferCard(BuildContext context, AffiliateTransferRecord r) {
    final scheme = Theme.of(context).colorScheme;
    final muted = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: scheme.onSurfaceVariant);
    String q(num? v) => v == null ? '-' : '\$${v.toStringAsFixed(2)}';
    return _cardShell(
      context,
      children: [
        Row(children: [
          Expanded(
              child:
                  _userRef(context, r.userId, r.userEmail, r.username, true)),
          Text('+\$${r.amount.toStringAsFixed(2)}',
              style: TextStyle(
                  color: scheme.tertiary, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 6),
        Wrap(spacing: 12, runSpacing: 2, children: [
          _miniStat(context, context.tr('adminAffiliates.balanceAfter'),
              q(r.balanceAfter)),
          _miniStat(context, context.tr('adminAffiliates.availableQuotaAfter'),
              q(r.availableQuotaAfter)),
          _miniStat(context, context.tr('adminAffiliates.frozenQuotaAfter'),
              q(r.frozenQuotaAfter)),
          _miniStat(context, context.tr('adminAffiliates.historyQuotaAfter'),
              q(r.historyQuotaAfter)),
        ]),
        const SizedBox(height: 2),
        Text(_fmt(r.createdAt), style: muted),
      ],
    );
  }

  Widget _cardShell(BuildContext context, {required List<Widget> children}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: children),
      ),
    );
  }

  Widget _userRef(BuildContext context, int id, String email, String username,
      bool clickable,
      {bool alignEnd = false}) {
    final scheme = Theme.of(context).colorScheme;
    final content = Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('#$id',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant)),
        Text(email.isEmpty ? '-' : email,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: alignEnd ? TextAlign.end : TextAlign.start,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: clickable ? scheme.primary : null,
                fontWeight: FontWeight.w500)),
        if (username.isNotEmpty)
          Text(username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: alignEnd ? TextAlign.end : TextAlign.start,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant)),
      ],
    );
    if (!clickable || id == 0) return content;
    return InkWell(
      onTap: () => _showOverview(context, id),
      borderRadius: BorderRadius.circular(6),
      child: content,
    );
  }

  Widget _miniStat(BuildContext context, String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant)),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }

  // ---------- 筛选/排序弹层 ----------

  void _showFilterSheet(BuildContext context, AffiliateRecordsState state,
      AffiliateRecordsController ctrl) {
    var startAt = state.startAt;
    var endAt = state.endAt;
    var sortBy = state.sortBy;
    var sortOrder = state.sortOrder;
    final sortKeys = _sortKeys(widget.type);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ctx.tr('adminAffiliates.filterSort'),
                    style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 12),
                Text(ctx.tr('adminAffiliates.dateRange'),
                    style: Theme.of(ctx).textTheme.labelMedium),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(
                    child: _dateButton(ctx, startAt,
                        ctx.tr('adminAffiliates.startAt'),
                        (v) => setS(() => startAt = v)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _dateButton(ctx, endAt,
                        ctx.tr('adminAffiliates.endAt'),
                        (v) => setS(() => endAt = v)),
                  ),
                ]),
                const SizedBox(height: 12),
                Text(ctx.tr('adminAffiliates.sortBy'),
                    style: Theme.of(ctx).textTheme.labelMedium),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  for (final k in sortKeys)
                    ChoiceChip(
                      label: Text(ctx.tr('adminAffiliates.sort_$k')),
                      selected: sortBy == k,
                      onSelected: (_) => setS(() => sortBy = k),
                    ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Text(ctx.tr('adminAffiliates.order'),
                      style: Theme.of(ctx).textTheme.labelMedium),
                  const SizedBox(width: 12),
                  ChoiceChip(
                    label: Text(ctx.tr('adminAffiliates.desc')),
                    selected: sortOrder == 'desc',
                    onSelected: (_) => setS(() => sortOrder = 'desc'),
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: Text(ctx.tr('adminAffiliates.asc')),
                    selected: sortOrder == 'asc',
                    onSelected: (_) => setS(() => sortOrder = 'asc'),
                  ),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setS(() {
                        startAt = '';
                        endAt = '';
                        sortBy = 'created_at';
                        sortOrder = 'desc';
                      }),
                      child: Text(ctx.tr('adminAffiliates.reset')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        ctrl.applyFilters(startAt: startAt, endAt: endAt);
                        ctrl.setSort(sortBy, sortOrder);
                        Navigator.pop(ctx);
                      },
                      child: Text(ctx.tr('adminAffiliates.apply')),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dateButton(BuildContext context, String value, String hint,
      ValueChanged<String> onChanged) {
    return OutlinedButton.icon(
      onPressed: () async {
        final now = DateTime.now();
        final initial = value.isEmpty
            ? now
            : (DateTime.tryParse(value) ?? now);
        final picked = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: DateTime(2020),
          lastDate: DateTime(now.year + 1),
        );
        if (picked != null) onChanged(formatDate(picked));
      },
      icon: const Icon(Icons.calendar_today, size: 16),
      label: Text(value.isEmpty ? hint : value,
          overflow: TextOverflow.ellipsis),
    );
  }

  static List<String> _sortKeys(AffiliateRecordType type) => switch (type) {
        AffiliateRecordType.invites => const ['created_at', 'total_rebate'],
        AffiliateRecordType.rebates =>
          const ['created_at', 'order_amount', 'pay_amount'],
        AffiliateRecordType.transfers => const ['created_at', 'amount'],
      };

  // ---------- 用户概览弹层 ----------

  void _showOverview(BuildContext context, int userId) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => _OverviewSheet(userId: userId),
    );
  }

  static String _fmt(String raw) {
    if (raw.isEmpty) return '-';
    final d = DateTime.tryParse(raw);
    return d == null ? raw : formatDateTime(d.toLocal());
  }
}

class _OverviewSheet extends ConsumerWidget {
  const _OverviewSheet({required this.userId});
  final int userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(affiliateUserOverviewProvider(userId));
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: async.when(
          loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: Text('$e'),
          ),
          data: (o) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr('adminAffiliates.overviewTitle'),
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('#${o.userId}',
                        style: Theme.of(context).textTheme.labelSmall),
                    Text(o.email.isEmpty ? '-' : o.email,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    if (o.username.isNotEmpty)
                      Text(o.username,
                          style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 12, runSpacing: 12, children: [
                _stat(context, context.tr('adminAffiliates.ovAffCode'),
                    o.affCode.isEmpty ? '-' : o.affCode),
                _stat(context, context.tr('adminAffiliates.ovRebateRate'),
                    '${_pct(o.rebateRatePercent)}%'),
                _stat(context, context.tr('adminAffiliates.ovInvitedCount'),
                    '${o.invitedCount}'),
                _stat(
                    context,
                    context.tr('adminAffiliates.ovRebatedInviteeCount'),
                    '${o.rebatedInviteeCount}'),
                _stat(context, context.tr('adminAffiliates.ovAvailableQuota'),
                    '\$${o.availableQuota.toStringAsFixed(2)}'),
                _stat(context, context.tr('adminAffiliates.ovHistoryQuota'),
                    '\$${o.historyQuota.toStringAsFixed(2)}'),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  static String _pct(num v) {
    final r = (v * 100).round() / 100;
    return r == r.roundToDouble() ? '${r.toInt()}' : '$r';
  }
}
