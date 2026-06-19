import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../i18n/app_localizations.dart';
import '../../../../shared/format/formatters.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_retry.dart';
import '../../../../shared/widgets/responsive.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../../../../shared/widgets/token_composition.dart';
import '../../accounts/providers/admin_accounts_providers.dart';
import '../data/admin_usage_api.dart';
import '../providers/admin_usage_providers.dart';

const _requestTypes = ['', 'sync', 'stream', 'ws_v2'];

/// 管理端使用记录:统计 + 时间范围 + 多维筛选 + 日志列表 + 记录详情 + 清理任务入口。
class AdminUsageListPage extends ConsumerStatefulWidget {
  const AdminUsageListPage({super.key});

  @override
  ConsumerState<AdminUsageListPage> createState() => _AdminUsageListPageState();
}

class _AdminUsageListPageState extends ConsumerState<AdminUsageListPage> {
  final _scroll = ScrollController();
  String _preset = '7d';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
        ref.read(adminUsageControllerProvider.notifier).loadMore();
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
    final state = ref.watch(adminUsageControllerProvider);
    final ctrl = ref.read(adminUsageControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('adminUsage.title')),
        actions: [
          IconButton(
            tooltip: context.tr('adminUsage.cleanup'),
            icon: const Icon(Icons.cleaning_services_outlined),
            onPressed: () => context.push('/admin/usage/cleanup'),
          ),
        ],
      ),
      body: Column(
        children: [
          _toolbar(context, state, ctrl),
          Expanded(child: _body(context, state, ctrl)),
        ],
      ),
    );
  }

  Widget _toolbar(
      BuildContext context, AdminUsageState state, AdminUsageController ctrl) {
    final filterBtn = IconButton.filledTonal(
      onPressed: () => _openFilters(context, state, ctrl),
      tooltip: context.tr('adminUsage.filters'),
      icon: const Icon(Icons.tune),
    );
    return ResponsiveCenter(
      maxWidth: 1100,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final p in const ['today', '7d', '30d', 'custom'])
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(context.tr('adminUsage.range_$p')),
                          selected: _preset == p,
                          onSelected: (_) => _applyPreset(p, ctrl),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            state.activeFilterCount > 0
                ? Badge.count(count: state.activeFilterCount, child: filterBtn)
                : filterBtn,
          ],
        ),
      ),
    );
  }

  Future<void> _applyPreset(String p, AdminUsageController ctrl) async {
    final now = DateTime.now();
    if (p == 'custom') {
      final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(now.year + 1),
        initialDateRange: DateTimeRange(
            start: now.subtract(const Duration(days: 7)), end: now),
      );
      if (range == null) return;
      setState(() => _preset = 'custom');
      ctrl.setDateRange(formatDate(range.start), formatDate(range.end));
      return;
    }
    final start = switch (p) {
      'today' => now,
      '30d' => now.subtract(const Duration(days: 29)),
      _ => now.subtract(const Duration(days: 6)),
    };
    setState(() => _preset = p);
    ctrl.setDateRange(formatDate(start), formatDate(now));
  }

  Widget _body(
      BuildContext context, AdminUsageState state, AdminUsageController ctrl) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.items.isEmpty) {
      return ErrorRetryView(error: state.error!, onRetry: ctrl.refresh);
    }
    return RefreshIndicator(
      onRefresh: ctrl.refresh,
      child: ResponsiveCenter(
        maxWidth: 1100,
        child: ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 24),
          itemCount: state.items.length + 2,
          itemBuilder: (context, i) {
            if (i == 0) return _statsCard(context, state.stats);
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
                    icon: Icons.insights_outlined,
                    message: context.tr('adminUsage.empty'));
              }
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Center(
                  child: Text(
                    context
                        .tr('adminUsage.total', params: {'n': '${state.total}'}),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              );
            }
            return _LogCard(
                log: state.items[idx], onTap: () => _showDetail(state.items[idx]));
          },
        ),
      ),
    );
  }

  Widget _statsCard(BuildContext context, AdminUsageStats? s) {
    if (s == null) return const SizedBox(height: 8);
    final cells = <(String, String)>[
      (formatInt(s.totalRequests), context.tr('adminUsage.statRequests')),
      (formatCompact(s.totalTokens), context.tr('adminUsage.statTokens')),
      (formatCost(s.totalCost.toDouble()), context.tr('adminUsage.statCost')),
      (formatCost(s.totalActualCost.toDouble()),
          context.tr('adminUsage.statActualCost')),
      (formatCost(s.totalAccountCost.toDouble()),
          context.tr('adminUsage.statAccountCost')),
      ('${(s.averageDurationMs / 1000).toStringAsFixed(2)}s',
          context.tr('adminUsage.statAvgDuration')),
    ];
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth >= 560 ? 6 : 3;
          return Wrap(
            children: [
              for (final cell in cells)
                SizedBox(
                  width: c.maxWidth / cols,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(cell.$1,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(cell.$2,
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant)),
                    ],
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }

  Future<void> _openFilters(
      BuildContext context, AdminUsageState state, AdminUsageController ctrl) async {
    int? userId = state.userId;
    var userEmail = state.userEmail;
    int? groupId = state.groupId;
    final modelCtrl = TextEditingController(text: state.model);
    var requestType = state.requestType;
    final groups = ref.read(adminGroupsAllProvider).value ?? const [];

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(
              16, 0, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ctx.tr('adminUsage.fUser'),
                    style: Theme.of(ctx).textTheme.labelLarge),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await _pickUser(ctx);
                    if (picked != null) {
                      setS(() {
                        userId = picked.id;
                        userEmail = picked.email;
                      });
                    }
                  },
                  icon: const Icon(Icons.person_search, size: 18),
                  label: Text(userId == null
                      ? ctx.tr('adminUsage.allUsers')
                      : userEmail),
                ),
                if (userId != null)
                  TextButton(
                    onPressed: () => setS(() {
                      userId = null;
                      userEmail = '';
                    }),
                    child: Text(ctx.tr('adminUsage.clearUser')),
                  ),
                const SizedBox(height: 12),
                Text(ctx.tr('adminUsage.fGroup'),
                    style: Theme.of(ctx).textTheme.labelLarge),
                const SizedBox(height: 6),
                DropdownButtonFormField<int?>(
                  initialValue: groupId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      isDense: true, border: OutlineInputBorder()),
                  items: [
                    DropdownMenuItem(
                        value: null, child: Text(ctx.tr('adminUsage.allGroups'))),
                    for (final g in groups)
                      DropdownMenuItem(value: g.id, child: Text(g.name)),
                  ],
                  onChanged: (v) => setS(() => groupId = v),
                ),
                const SizedBox(height: 12),
                Text(ctx.tr('adminUsage.fModel'),
                    style: Theme.of(ctx).textTheme.labelLarge),
                const SizedBox(height: 6),
                TextField(
                  controller: modelCtrl,
                  decoration: InputDecoration(
                    isDense: true,
                    border: const OutlineInputBorder(),
                    hintText: ctx.tr('adminUsage.modelHint'),
                  ),
                ),
                const SizedBox(height: 12),
                Text(ctx.tr('adminUsage.fType'),
                    style: Theme.of(ctx).textTheme.labelLarge),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  for (final t in _requestTypes)
                    ChoiceChip(
                      label: Text(t.isEmpty
                          ? ctx.tr('adminUsage.allTypes')
                          : ctx.tr('adminUsage.type_$t')),
                      selected: requestType == t,
                      onSelected: (_) => setS(() => requestType = t),
                    ),
                ]),
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        userId = null;
                        userEmail = '';
                        groupId = null;
                        modelCtrl.text = '';
                        requestType = '';
                        Navigator.pop(ctx, true);
                      },
                      child: Text(ctx.tr('adminUsage.reset')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(ctx.tr('adminUsage.apply')),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok == true) {
      ctrl.applyFilters(
        userId: userId,
        userEmail: userEmail,
        groupId: groupId,
        model: modelCtrl.text.trim(),
        requestType: requestType,
      );
    }
  }

  Future<UsageSimpleUser?> _pickUser(BuildContext context) async {
    final searchCtrl = TextEditingController();
    var results = <UsageSimpleUser>[];
    var loading = false;
    return showDialog<UsageSimpleUser>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('adminUsage.pickUser')),
        content: SizedBox(
          width: 360,
          child: StatefulBuilder(
            builder: (ctx, setS) {
              Future<void> doSearch() async {
                setS(() => loading = true);
                try {
                  results = await ref
                      .read(adminUsageApiProvider)
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
                    hintText: ctx.tr('adminUsage.userEmailHint'),
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
                              child: Text(ctx.tr('adminUsage.noUsersFound'),
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
                                onTap: () => Navigator.pop(ctx, results[i]),
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

  void _showDetail(AdminUsageLog log) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _DetailSheet(log: log),
    );
  }
}

class _LogCard extends StatelessWidget {
  const _LogCard({required this.log, required this.onTap});
  final AdminUsageLog log;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final when = log.createdAt == null ? null : DateTime.tryParse(log.createdAt!);
    final type = log.resolvedType;
    final meta = <String>[
      if ((log.userEmail ?? '').isNotEmpty) log.userEmail!,
      if ((log.groupName ?? '').isNotEmpty) log.groupName!,
      if ((log.accountName ?? '').isNotEmpty) log.accountName!,
    ].join('  ·  ');
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(log.model,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                ),
                StatusPill(
                    label: context.tr('adminUsage.type_$type'),
                    tone: type == 'sync' ? StatusTone.neutral : StatusTone.info,
                    dense: true),
                const SizedBox(width: 6),
                Text(formatCost(log.totalCost.toDouble()),
                    style: TextStyle(
                        color: scheme.primary, fontWeight: FontWeight.w700)),
              ]),
              if (meta.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(meta,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 2),
              Text(
                '${formatCompact(log.totalTokens)} tok'
                '${when == null ? '' : '  ·  ${formatDateTime(when.toLocal())}'}'
                '${log.durationMs == null ? '' : '  ·  ${(log.durationMs! / 1000).toStringAsFixed(1)}s'}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailSheet extends StatelessWidget {
  const _DetailSheet({required this.log});
  final AdminUsageLog log;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final when =
        log.createdAt == null ? null : DateTime.tryParse(log.createdAt!);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Row(children: [
            Expanded(
              child: Text(log.model,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
            if (log.requestId != null)
              IconButton(
                icon: const Icon(Icons.copy, size: 18),
                tooltip: context.tr('adminUsage.copyRequestId'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: log.requestId!));
                  showAppToast(context, context.tr('common.done'));
                },
              ),
          ]),
          const SizedBox(height: 8),
          TokenComposition(segments: [
            TokenSegment(
                label: context.tr('adminUsage.tInput'),
                value: log.inputTokens,
                color: scheme.primary),
            TokenSegment(
                label: context.tr('adminUsage.tOutput'),
                value: log.outputTokens,
                color: scheme.tertiary),
            TokenSegment(
                label: context.tr('adminUsage.tCacheCreate'),
                value: log.cacheCreationTokens,
                color: const Color(0xFFB7791F)),
            TokenSegment(
                label: context.tr('adminUsage.tCacheRead'),
                value: log.cacheReadTokens,
                color: const Color(0xFF38A169)),
          ]),
          const SizedBox(height: 12),
          _kv(context, 'adminUsage.dUser', log.userEmail ?? '#${log.userId}'),
          _kv(context, 'adminUsage.dApiKey', log.apiKeyName),
          _kv(context, 'adminUsage.dGroup', log.groupName),
          _kv(context, 'adminUsage.dAccount', log.accountName),
          _kv(context, 'adminUsage.dUpstreamModel', log.upstreamModel),
          _kv(context, 'adminUsage.dType',
              context.tr('adminUsage.type_${log.resolvedType}')),
          _kv(context, 'adminUsage.dInbound', log.inboundEndpoint),
          _kv(context, 'adminUsage.dUpstream', log.upstreamEndpoint),
          _kv(context, 'adminUsage.dBillingMode', log.billingMode),
          const Divider(height: 24),
          _kv(context, 'adminUsage.dInputCost',
              formatCost(log.inputCost.toDouble(), decimals: 6)),
          _kv(context, 'adminUsage.dOutputCost',
              formatCost(log.outputCost.toDouble(), decimals: 6)),
          _kv(context, 'adminUsage.dCacheCreateCost',
              formatCost(log.cacheCreationCost.toDouble(), decimals: 6)),
          _kv(context, 'adminUsage.dCacheReadCost',
              formatCost(log.cacheReadCost.toDouble(), decimals: 6)),
          _kv(context, 'adminUsage.dRate', '×${log.rateMultiplier}'),
          if (log.accountRateMultiplier != null)
            _kv(context, 'adminUsage.dAccountRate',
                '×${log.accountRateMultiplier}'),
          _kv(context, 'adminUsage.dTotalCost',
              formatCost(log.totalCost.toDouble(), decimals: 6)),
          _kv(context, 'adminUsage.dActualCost',
              formatCost(log.actualCost.toDouble(), decimals: 6)),
          _kv(context, 'adminUsage.dAccountCost',
              formatCost(log.accountCost.toDouble(), decimals: 6)),
          const Divider(height: 24),
          if (log.firstTokenMs != null)
            _kv(context, 'adminUsage.dFirstToken',
                '${log.firstTokenMs!.toStringAsFixed(0)}ms'),
          if (log.durationMs != null)
            _kv(context, 'adminUsage.dDuration',
                '${(log.durationMs! / 1000).toStringAsFixed(2)}s'),
          _kv(context, 'adminUsage.dRequestId', log.requestId),
          _kv(context, 'adminUsage.dIp', log.ipAddress),
          _kv(context, 'adminUsage.dUserAgent', log.userAgent),
          if (when != null)
            _kv(context, 'adminUsage.dTime', formatDateTime(when.toLocal())),
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String labelKey, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(context.tr(labelKey),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(value,
                style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
