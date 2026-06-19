import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../i18n/app_localizations.dart';
import '../../../../shared/format/formatters.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_retry.dart';
import '../../../../shared/widgets/responsive.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../data/admin_ops_api.dart';
import '../providers/admin_ops_providers.dart';

const _errTimeRanges = ['1h', '6h', '24h', '7d', '30d'];
const _resolvedOptions = ['', 'false', 'true'];

StatusTone severityTone(String severity) => switch (severity) {
      'critical' => StatusTone.danger,
      'warning' => StatusTone.warning,
      'info' => StatusTone.info,
      _ => StatusTone.neutral,
    };

StatusTone statusCodeTone(int code) {
  if (code >= 500) return StatusTone.danger;
  if (code >= 400) return StatusTone.warning;
  return StatusTone.neutral;
}

/// 运维错误日志 Tab。
class OpsErrorsTab extends ConsumerStatefulWidget {
  const OpsErrorsTab({super.key});

  @override
  ConsumerState<OpsErrorsTab> createState() => _OpsErrorsTabState();
}

class _OpsErrorsTabState extends ConsumerState<OpsErrorsTab>
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
        ref.read(opsErrorsControllerProvider.notifier).loadMore();
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
    final state = ref.watch(opsErrorsControllerProvider);
    final ctrl = ref.read(opsErrorsControllerProvider.notifier);
    final hasFilters = state.resolved.isNotEmpty || state.timeRange != '24h';
    return Column(
      children: [
        ResponsiveCenter(
          maxWidth: 1100,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onSubmitted: ctrl.setSearch,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: context.tr('adminOps.errSearchHint'),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                  tooltip: context.tr('adminOps.filters'),
                ),
              ),
            ]),
          ),
        ),
        Expanded(child: _body(context, state, ctrl)),
      ],
    );
  }

  Widget _body(BuildContext context, OpsErrorsState state,
      OpsErrorsController ctrl) {
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
              icon: Icons.error_outline,
              message: context.tr('adminOps.emptyErrors')),
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
                    context.tr('adminOps.total', params: {'n': '${state.total}'}),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              );
            }
            return _ErrorCard(
              log: state.items[i],
              onTap: () => _showDetail(context, state.items[i]),
            );
          },
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, OpsErrorLog log) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ErrorDetailSheet(
        log: log,
        onResolvedChanged: () =>
            ref.read(opsErrorsControllerProvider.notifier).refresh(),
      ),
    );
  }

  void _showFilters(
      BuildContext context, OpsErrorsState state, OpsErrorsController ctrl) {
    var timeRange = state.timeRange;
    var resolved = state.resolved;
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
                Text(ctx.tr('adminOps.filters'),
                    style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 12),
                Text(ctx.tr('adminOps.timeRange'),
                    style: Theme.of(ctx).textTheme.labelMedium),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  for (final r in _errTimeRanges)
                    ChoiceChip(
                      label: Text(r),
                      selected: timeRange == r,
                      onSelected: (_) => setS(() => timeRange = r),
                    ),
                ]),
                const SizedBox(height: 12),
                Text(ctx.tr('adminOps.resolvedFilter'),
                    style: Theme.of(ctx).textTheme.labelMedium),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  for (final r in _resolvedOptions)
                    ChoiceChip(
                      label: Text(switch (r) {
                        'true' => ctx.tr('adminOps.resolved'),
                        'false' => ctx.tr('adminOps.unresolved'),
                        _ => ctx.tr('adminOps.allResolved'),
                      }),
                      selected: resolved == r,
                      onSelected: (_) => setS(() => resolved = r),
                    ),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setS(() {
                        timeRange = '24h';
                        resolved = '';
                      }),
                      child: Text(ctx.tr('adminOps.reset')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        ctrl.applyFilters(
                            timeRange: timeRange, resolved: resolved);
                        Navigator.pop(ctx);
                      },
                      child: Text(ctx.tr('adminOps.apply')),
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
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.log, required this.onTap});
  final OpsErrorLog log;
  final VoidCallback onTap;

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
                    label: '${log.statusCode}',
                    tone: statusCodeTone(log.statusCode),
                    dense: true),
                const SizedBox(width: 6),
                if (log.severity.isNotEmpty)
                  StatusPill(
                      label: log.severity,
                      tone: severityTone(log.severity),
                      dense: true),
                const Spacer(),
                if (log.resolved)
                  Icon(Icons.check_circle, size: 16, color: Colors.green),
                const SizedBox(width: 4),
                Text(_fmt(log.createdAt), style: muted),
              ]),
              const SizedBox(height: 4),
              Text(log.message.isEmpty ? log.type : log.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 2),
              Wrap(spacing: 8, runSpacing: 2, children: [
                if (log.platform.isNotEmpty) Text(log.platform, style: muted),
                if (log.model.isNotEmpty) ...[
                  Text('·', style: muted),
                  Text(log.model, style: muted),
                ],
                if (log.userEmail.isNotEmpty) ...[
                  Text('·', style: muted),
                  Text(log.userEmail, style: muted),
                ],
                if (log.groupName.isNotEmpty) ...[
                  Text('·', style: muted),
                  Text(log.groupName, style: muted),
                ],
              ]),
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

class _ErrorDetailSheet extends ConsumerStatefulWidget {
  const _ErrorDetailSheet({required this.log, required this.onResolvedChanged});
  final OpsErrorLog log;
  final VoidCallback onResolvedChanged;

  @override
  ConsumerState<_ErrorDetailSheet> createState() => _ErrorDetailSheetState();
}

class _ErrorDetailSheetState extends ConsumerState<_ErrorDetailSheet> {
  OpsErrorDetail? _detail;
  late bool _resolved = widget.log.resolved;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await ref.read(adminOpsApiProvider).getErrorLogDetail(widget.log.id);
      if (mounted) setState(() => _detail = d);
    } catch (_) {/* keep summary */}
  }

  Future<void> _toggleResolved(bool v) async {
    setState(() => _saving = true);
    try {
      await ref.read(adminOpsApiProvider).updateErrorResolved(widget.log.id, v);
      setState(() => _resolved = v);
      widget.onResolvedChanged();
    } catch (e) {
      if (mounted) showAppToast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final log = _detail?.log ?? widget.log;
    final d = _detail;
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
            StatusPill(
                label: '${log.statusCode}',
                tone: statusCodeTone(log.statusCode)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(context.tr('adminOps.errorDetail'),
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            _saving
                ? const SizedBox(
                    width: 36,
                    height: 20,
                    child: Center(
                        child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))))
                : Switch(value: _resolved, onChanged: _toggleResolved),
          ]),
          Text(context.tr('adminOps.markResolved'),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          _kv(context, 'adminOps.colTime', _fmt(log.createdAt)),
          _kv(context, 'adminOps.type', '${log.type} · ${log.phase}'),
          _kv(context, 'adminOps.owner', '${log.errorOwner} / ${log.errorSource}'),
          if (log.platform.isNotEmpty)
            _kv(context, 'adminOps.platform', log.platform),
          if (log.model.isNotEmpty) _kv(context, 'adminOps.model', log.model),
          if ((log.requestedModel ?? '').isNotEmpty)
            _kv(context, 'adminOps.requestedModel', log.requestedModel!),
          if (log.userEmail.isNotEmpty)
            _kv(context, 'adminOps.user', log.userEmail),
          if ((log.apiKeyName ?? '').isNotEmpty)
            _kv(context, 'adminOps.apiKey', log.apiKeyName!),
          if (log.accountName.isNotEmpty)
            _kv(context, 'adminOps.account', log.accountName),
          if (log.groupName.isNotEmpty)
            _kv(context, 'adminOps.group', log.groupName),
          if ((log.requestPath ?? '').isNotEmpty)
            _kv(context, 'adminOps.requestPath', log.requestPath!),
          if (log.requestId.isNotEmpty)
            _kv(context, 'adminOps.requestId', log.requestId),
          if (d != null) ...[
            if ((d.clientIp ?? '').isNotEmpty)
              _kv(context, 'adminOps.clientIp', d.clientIp!),
            if (d.upstreamStatusCode != null)
              _kv(context, 'adminOps.upstreamStatus', '${d.upstreamStatusCode}'),
            if (d.upstreamLatencyMs != null)
              _kv(context, 'adminOps.upstreamLatency',
                  '${d.upstreamLatencyMs} ms'),
            if (d.timeToFirstTokenMs != null)
              _kv(context, 'adminOps.ttft', '${d.timeToFirstTokenMs} ms'),
            if (d.responseLatencyMs != null)
              _kv(context, 'adminOps.responseLatency',
                  '${d.responseLatencyMs} ms'),
          ],
          const Divider(height: 24),
          Text(context.tr('adminOps.errorBody'),
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              (d?.errorBody.isNotEmpty ?? false)
                  ? d!.errorBody
                  : (log.message.isNotEmpty ? log.message : '-'),
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
            width: 104,
            child: Text(context.tr(labelKey),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant)),
          ),
          Expanded(
              child: SelectableText(value,
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
