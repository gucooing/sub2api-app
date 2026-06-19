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
import '../data/admin_ops_api.dart';
import '../providers/admin_ops_providers.dart';

const _sysTimeRanges = ['5m', '30m', '1h', '6h', '24h', '7d'];
const _levels = ['', 'debug', 'info', 'warn', 'error'];

StatusTone levelTone(String level) => switch (level.toLowerCase()) {
      'error' || 'fatal' => StatusTone.danger,
      'warn' || 'warning' => StatusTone.warning,
      'info' => StatusTone.info,
      _ => StatusTone.neutral,
    };

/// 运维系统日志 Tab。
class OpsSystemLogsTab extends ConsumerStatefulWidget {
  const OpsSystemLogsTab({super.key});

  @override
  ConsumerState<OpsSystemLogsTab> createState() => _OpsSystemLogsTabState();
}

class _OpsSystemLogsTabState extends ConsumerState<OpsSystemLogsTab>
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
        ref.read(opsSystemLogsControllerProvider.notifier).loadMore();
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
    final state = ref.watch(opsSystemLogsControllerProvider);
    final ctrl = ref.read(opsSystemLogsControllerProvider.notifier);
    final hasFilters =
        state.level.isNotEmpty || state.component.isNotEmpty || state.timeRange != '1h';
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
                    hintText: context.tr('adminOps.sysSearchHint'),
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
              IconButton(
                onPressed: () => _cleanup(context, state),
                icon: const Icon(Icons.delete_sweep_outlined),
                tooltip: context.tr('adminOps.cleanup'),
              ),
            ]),
          ),
        ),
        Expanded(child: _body(context, state, ctrl)),
      ],
    );
  }

  Widget _body(BuildContext context, OpsSystemLogsState state,
      OpsSystemLogsController ctrl) {
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
              icon: Icons.article_outlined,
              message: context.tr('adminOps.emptyLogs')),
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
            return _LogCard(log: state.items[i]);
          },
        ),
      ),
    );
  }

  Future<void> _cleanup(BuildContext context, OpsSystemLogsState state) async {
    final ok = await showConfirmDialog(
      context,
      title: context.tr('adminOps.cleanup'),
      message: context.tr('adminOps.cleanupConfirm'),
      confirmLabel: context.tr('common.delete'),
      destructive: true,
    );
    if (!ok) return;
    try {
      final n = await ref.read(adminOpsApiProvider).cleanupSystemLogs(
            level: state.level,
            component: state.component,
            q: state.search,
          );
      ref.read(opsSystemLogsControllerProvider.notifier).refresh();
      if (context.mounted) {
        showAppToast(
            context, context.tr('adminOps.cleaned', params: {'n': '$n'}));
      }
    } catch (e) {
      if (context.mounted) showAppToast(context, '$e', error: true);
    }
  }

  void _showFilters(BuildContext context, OpsSystemLogsState state,
      OpsSystemLogsController ctrl) {
    var timeRange = state.timeRange;
    var level = state.level;
    final componentCtrl = TextEditingController(text: state.component);
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
                  for (final r in _sysTimeRanges)
                    ChoiceChip(
                      label: Text(r),
                      selected: timeRange == r,
                      onSelected: (_) => setS(() => timeRange = r),
                    ),
                ]),
                const SizedBox(height: 12),
                Text(ctx.tr('adminOps.level'),
                    style: Theme.of(ctx).textTheme.labelMedium),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  for (final l in _levels)
                    ChoiceChip(
                      label: Text(
                          l.isEmpty ? ctx.tr('adminOps.allLevels') : l),
                      selected: level == l,
                      onSelected: (_) => setS(() => level = l),
                    ),
                ]),
                const SizedBox(height: 12),
                TextField(
                  controller: componentCtrl,
                  decoration: InputDecoration(
                    labelText: ctx.tr('adminOps.component'),
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setS(() {
                        timeRange = '1h';
                        level = '';
                        componentCtrl.clear();
                      }),
                      child: Text(ctx.tr('adminOps.reset')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        ctrl.applyFilters(
                            timeRange: timeRange,
                            level: level,
                            component: componentCtrl.text.trim());
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

class _LogCard extends StatelessWidget {
  const _LogCard({required this.log});
  final OpsSystemLog log;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: scheme.onSurfaceVariant);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              StatusPill(
                  label: log.level.isEmpty ? '-' : log.level,
                  tone: levelTone(log.level),
                  dense: true),
              const SizedBox(width: 6),
              Expanded(
                child: Text(log.component,
                    style: muted, overflow: TextOverflow.ellipsis),
              ),
              Text(_fmt(log.createdAt), style: muted),
            ]),
            const SizedBox(height: 4),
            SelectableText(log.message,
                maxLines: 4,
                style: Theme.of(context).textTheme.bodyMedium),
            if ((log.requestId ?? '').isNotEmpty ||
                (log.platform ?? '').isNotEmpty ||
                (log.model ?? '').isNotEmpty) ...[
              const SizedBox(height: 2),
              Wrap(spacing: 8, runSpacing: 2, children: [
                if ((log.platform ?? '').isNotEmpty)
                  Text(log.platform!, style: muted),
                if ((log.model ?? '').isNotEmpty) ...[
                  Text('·', style: muted),
                  Text(log.model!, style: muted),
                ],
                if ((log.requestId ?? '').isNotEmpty) ...[
                  Text('·', style: muted),
                  Text(log.requestId!,
                      style: muted?.copyWith(fontFamily: 'monospace')),
                ],
              ]),
            ],
          ],
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
