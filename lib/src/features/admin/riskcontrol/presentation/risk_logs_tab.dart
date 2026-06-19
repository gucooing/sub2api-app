import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../i18n/app_localizations.dart';
import '../../../../shared/format/formatters.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_retry.dart';
import '../../../../shared/widgets/responsive.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../../groups/providers/admin_groups_providers.dart';
import '../data/admin_risk_control_api.dart';
import '../providers/admin_risk_control_providers.dart';

const _resultOptions = ['', 'hit', 'blocked', 'pass', 'error'];
const _endpointOptions = [
  '',
  '/v1/messages',
  '/v1/responses',
  '/v1/chat/completions',
  '/v1beta/models',
  '/v1/images/generations',
  '/v1/images/edits',
];

String logResultLabel(BuildContext context, ModerationLog r) {
  if (r.action == 'keyword_block') return context.tr('adminRisk.action_keyword_block');
  if (r.action == 'block') return context.tr('adminRisk.action_block');
  if (r.action == 'error' || r.error.isNotEmpty) {
    return context.tr('adminRisk.action_error');
  }
  if (r.flagged) return context.tr('adminRisk.result_hit');
  return context.tr('adminRisk.result_pass');
}

StatusTone logResultTone(ModerationLog r) {
  if (r.action == 'block' || r.action == 'keyword_block') return StatusTone.danger;
  if (r.action == 'error' || r.error.isNotEmpty) return StatusTone.warning;
  if (r.flagged) return StatusTone.info;
  return StatusTone.positive;
}

String pct(num v) => '${(v * 100).toStringAsFixed(1)}%';

/// 风控审核日志 Tab。
class RiskLogsTab extends ConsumerStatefulWidget {
  const RiskLogsTab({super.key});

  @override
  ConsumerState<RiskLogsTab> createState() => _RiskLogsTabState();
}

class _RiskLogsTabState extends ConsumerState<RiskLogsTab>
    with AutomaticKeepAliveClientMixin {
  final _scroll = ScrollController();
  final _searchCtrl = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
        ref.read(moderationLogsControllerProvider.notifier).loadMore();
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
    final state = ref.watch(moderationLogsControllerProvider);
    final ctrl = ref.read(moderationLogsControllerProvider.notifier);
    final hasFilters = state.result.isNotEmpty ||
        state.groupId > 0 ||
        state.endpoint.isNotEmpty ||
        state.from.isNotEmpty ||
        state.to.isNotEmpty;
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
                      hintText: context.tr('adminRisk.searchHint'),
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
                    onPressed: () => _showFilters(context, state, ctrl),
                    icon: const Icon(Icons.tune),
                    tooltip: context.tr('adminRisk.filters'),
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

  Widget _body(BuildContext context, ModerationLogsState state,
      ModerationLogsController ctrl) {
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
              icon: Icons.shield_outlined,
              message: context.tr('adminRisk.emptyLogs')),
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
                    context.tr('adminRisk.totalLogs',
                        params: {'n': '${state.total}'}),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              );
            }
            return _LogCard(
              log: state.items[i],
              onTap: () => _showDetail(context, state.items[i]),
              onUnban: () => _unban(context, ctrl, state.items[i]),
            );
          },
        ),
      ),
    );
  }

  Future<void> _unban(BuildContext context, ModerationLogsController ctrl,
      ModerationLog log) async {
    final uid = log.userId;
    if (uid == null) return;
    try {
      final status = await ref.read(adminRiskControlApiProvider).unbanUser(uid);
      ctrl.markUserStatus(uid, status);
      if (context.mounted) {
        showAppToast(context, context.tr('adminRisk.unbanSuccess'));
      }
    } catch (e) {
      if (context.mounted) showAppToast(context, '$e', error: true);
    }
  }

  void _showDetail(BuildContext context, ModerationLog log) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _LogDetailSheet(log: log),
    );
  }

  void _showFilters(BuildContext context, ModerationLogsState state,
      ModerationLogsController ctrl) {
    var result = state.result;
    var groupId = state.groupId;
    var endpoint = state.endpoint;
    var from = state.from;
    var to = state.to;
    final groups = ref.read(adminGroupsFullProvider).value ?? const [];
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
                Text(ctx.tr('adminRisk.filters'),
                    style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 12),
                Text(ctx.tr('adminRisk.filterResult'),
                    style: Theme.of(ctx).textTheme.labelMedium),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  for (final r in _resultOptions)
                    ChoiceChip(
                      label: Text(r.isEmpty
                          ? ctx.tr('adminRisk.result_all')
                          : ctx.tr('adminRisk.result_$r')),
                      selected: result == r,
                      onSelected: (_) => setS(() => result = r),
                    ),
                ]),
                const SizedBox(height: 12),
                Text(ctx.tr('adminRisk.filterEndpoint'),
                    style: Theme.of(ctx).textTheme.labelMedium),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  for (final e in _endpointOptions)
                    ChoiceChip(
                      label: Text(
                          e.isEmpty ? ctx.tr('adminRisk.allEndpoints') : e),
                      selected: endpoint == e,
                      onSelected: (_) => setS(() => endpoint = e),
                    ),
                ]),
                const SizedBox(height: 12),
                Text(ctx.tr('adminRisk.filterGroup'),
                    style: Theme.of(ctx).textTheme.labelMedium),
                const SizedBox(height: 6),
                DropdownButtonFormField<int>(
                  initialValue: groupId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      isDense: true, border: OutlineInputBorder()),
                  items: [
                    DropdownMenuItem(
                        value: 0, child: Text(ctx.tr('adminRisk.allGroups'))),
                    for (final g in groups)
                      DropdownMenuItem(
                          value: g.id,
                          child: Text('${g.name} (${g.platform})',
                              overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => setS(() => groupId = v ?? 0),
                ),
                const SizedBox(height: 12),
                Text(ctx.tr('adminRisk.dateRange'),
                    style: Theme.of(ctx).textTheme.labelMedium),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(
                      child: _dateBtn(ctx, from, ctx.tr('adminRisk.from'),
                          (v) => setS(() => from = v))),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _dateBtn(ctx, to, ctx.tr('adminRisk.to'),
                          (v) => setS(() => to = v))),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setS(() {
                        result = '';
                        groupId = 0;
                        endpoint = '';
                        from = '';
                        to = '';
                      }),
                      child: Text(ctx.tr('adminRisk.reset')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        ctrl.applyFilters(
                            result: result,
                            groupId: groupId,
                            endpoint: endpoint,
                            from: from,
                            to: to);
                        Navigator.pop(ctx);
                      },
                      child: Text(ctx.tr('adminRisk.apply')),
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

  Widget _dateBtn(BuildContext context, String value, String hint,
      ValueChanged<String> onChanged) {
    final shown = value.isEmpty
        ? hint
        : (DateTime.tryParse(value) != null
            ? formatDate(DateTime.parse(value).toLocal())
            : value);
    return OutlinedButton.icon(
      onPressed: () async {
        final now = DateTime.now();
        final init = value.isEmpty ? now : (DateTime.tryParse(value) ?? now);
        final picked = await showDatePicker(
          context: context,
          initialDate: init,
          firstDate: DateTime(2020),
          lastDate: DateTime(now.year + 1),
        );
        if (picked != null) onChanged(picked.toIso8601String());
      },
      icon: const Icon(Icons.calendar_today, size: 16),
      label: Text(shown, overflow: TextOverflow.ellipsis),
    );
  }
}

class _LogCard extends StatelessWidget {
  const _LogCard(
      {required this.log, required this.onTap, required this.onUnban});

  final ModerationLog log;
  final VoidCallback onTap;
  final VoidCallback onUnban;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: scheme.onSurfaceVariant);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                StatusPill(
                    label: logResultLabel(context, log),
                    tone: logResultTone(log),
                    dense: true),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(log.userEmail.isEmpty ? '-' : log.userEmail,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis),
                ),
                Text(_fmt(log.createdAt), style: muted),
              ]),
              const SizedBox(height: 4),
              Wrap(spacing: 8, runSpacing: 2, children: [
                if (log.groupName.isNotEmpty) Text(log.groupName, style: muted),
                if (log.endpoint.isNotEmpty) ...[
                  Text('·', style: muted),
                  Text(log.endpoint, style: muted),
                ],
                if (log.model.isNotEmpty) ...[
                  Text('·', style: muted),
                  Text(log.model, style: muted),
                ],
                if (log.highestCategory.isNotEmpty) ...[
                  Text('·', style: muted),
                  Text('${log.highestCategory} ${pct(log.highestScore)}',
                      style: muted?.copyWith(color: scheme.error)),
                ],
              ]),
              if (log.inputExcerpt.isNotEmpty || log.error.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                    log.inputExcerpt.isNotEmpty ? log.inputExcerpt : log.error,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: muted),
              ],
              if (log.canUnban) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onUnban,
                    icon: const Icon(Icons.lock_open, size: 16),
                    label: Text(context.tr('adminRisk.unbanUser')),
                    style:
                        TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _fmt(String raw) {
    if (raw.isEmpty) return '-';
    final d = DateTime.tryParse(raw);
    return d == null ? raw : formatDateTime(d.toLocal());
  }
}

class _LogDetailSheet extends StatelessWidget {
  const _LogDetailSheet({required this.log});
  final ModerationLog log;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cats = log.categoryScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Row(children: [
            Expanded(
              child: Text(context.tr('adminRisk.logDetail'),
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            StatusPill(
                label: logResultLabel(context, log), tone: logResultTone(log)),
          ]),
          const SizedBox(height: 12),
          _kv(context, 'adminRisk.colTime', _fmt(log.createdAt)),
          _kv(context, 'adminRisk.colUser',
              log.userEmail.isEmpty ? '#${log.userId ?? '-'}' : log.userEmail),
          if (log.groupName.isNotEmpty)
            _kv(context, 'adminRisk.colGroup', log.groupName),
          if (log.apiKeyName.isNotEmpty)
            _kv(context, 'adminRisk.colApiKey', log.apiKeyName),
          _kv(context, 'adminRisk.colEndpoint',
              '${log.endpoint} · ${log.provider}/${log.model}'),
          _kv(context, 'adminRisk.colMode', log.mode),
          if (log.highestCategory.isNotEmpty)
            _kv(context, 'adminRisk.colHighest',
                '${log.highestCategory} / ${pct(log.highestScore)}'),
          if (log.flagged)
            _kv(context, 'adminRisk.violationCount', '${log.violationCount}'),
          _kv(
              context,
              'adminRisk.emailSent',
              log.emailSent
                  ? context.tr('adminRisk.yes')
                  : context.tr('adminRisk.no')),
          if (log.autoBanned)
            _kv(context, 'adminRisk.autoBanned', context.tr('adminRisk.yes')),
          if (log.upstreamLatencyMs != null)
            _kv(context, 'adminRisk.colLatency', '${log.upstreamLatencyMs} ms'),
          if (cats.isNotEmpty) ...[
            const Divider(height: 24),
            Text(context.tr('adminRisk.categoryScores'),
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            for (final e in cats)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  Expanded(child: Text(e.key, style: Theme.of(context).textTheme.bodySmall)),
                  Text(pct(e.value),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: (log.thresholdSnapshot[e.key] ?? 1) <= e.value
                              ? scheme.error
                              : null)),
                  if (log.thresholdSnapshot[e.key] != null)
                    Text('  / ${pct(log.thresholdSnapshot[e.key]!)}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant)),
                ]),
              ),
          ],
          const Divider(height: 24),
          Text(context.tr('adminRisk.inputContent'),
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              log.inputExcerpt.isNotEmpty
                  ? log.inputExcerpt
                  : (log.error.isNotEmpty ? log.error : '-'),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String labelKey, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(context.tr(labelKey),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant)),
          ),
          Expanded(
              child: Text(value,
                  style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }

  static String _fmt(String raw) {
    if (raw.isEmpty) return '-';
    final d = DateTime.tryParse(raw);
    return d == null ? raw : formatDateTime(d.toLocal());
  }
}
