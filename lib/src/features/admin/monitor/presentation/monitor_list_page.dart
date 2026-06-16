import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../i18n/app_localizations.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_retry.dart';
import '../../../../shared/widgets/responsive.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../data/admin_monitor_api.dart';
import '../providers/admin_monitor_providers.dart';

/// 监控状态 → 色调。
StatusTone monitorTone(String status) => switch (status) {
      'operational' => StatusTone.positive,
      'degraded' => StatusTone.warning,
      'failed' || 'error' => StatusTone.danger,
      _ => StatusTone.neutral,
    };

String monitorStatusKey(String status) =>
    status.isEmpty ? 'adminMonitor.statusUnknown' : 'adminMonitor.status_$status';

enum _MonAction { run, toggle, delete }

/// 渠道监控:列表 + 平台筛选 + 立即检测 / 启停 / 删除 + 进详情。
class MonitorListPage extends ConsumerStatefulWidget {
  const MonitorListPage({super.key});

  @override
  ConsumerState<MonitorListPage> createState() => _MonitorListPageState();
}

class _MonitorListPageState extends ConsumerState<MonitorListPage> {
  final _scroll = ScrollController();
  final _searchCtrl = TextEditingController();
  int? _running;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
        ref.read(adminMonitorControllerProvider.notifier).loadMore();
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
    final state = ref.watch(adminMonitorControllerProvider);
    final ctrl = ref.read(adminMonitorControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('adminMonitor.title')),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(96),
          child: Column(children: [
            _searchBar(context, ctrl),
            _providerChips(context, state, ctrl),
          ]),
        ),
      ),
      body: _body(context, state, ctrl),
    );
  }

  Widget _searchBar(BuildContext context, AdminMonitorController ctrl) {
    return ResponsiveCenter(
      maxWidth: 1100,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
        child: SizedBox(
          height: 48,
          child: TextField(
            controller: _searchCtrl,
            onSubmitted: ctrl.setSearch,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: context.tr('adminMonitor.searchHint'),
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _providerChips(
      BuildContext context, AdminMonitorState state, AdminMonitorController ctrl) {
    return SizedBox(
      height: 44,
      child: ResponsiveCenter(
        maxWidth: 1100,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          children: [
            for (final p in const ['', 'openai', 'anthropic', 'gemini'])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(p.isEmpty ? context.tr('adminMonitor.all') : p),
                  selected: state.provider == p,
                  onSelected: (_) => ctrl.setProvider(p),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, AdminMonitorState state,
      AdminMonitorController ctrl) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.items.isEmpty) {
      return ErrorRetryView(error: state.error!, onRetry: ctrl.refresh);
    }
    if (state.items.isEmpty) {
      return EmptyState(
        icon: Icons.monitor_heart_outlined,
        message: context.tr('adminMonitor.empty'),
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
              return state.loadingMore
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()))
                  : const SizedBox(height: 8);
            }
            final m = state.items[i];
            return _MonitorCard(
              monitor: m,
              running: _running == m.id,
              onTap: () => context.push('/admin/monitor/${m.id}'),
              onAction: (a) => _runAction(context, ctrl, m, a),
            );
          },
        ),
      ),
    );
  }

  Future<void> _runAction(BuildContext context, AdminMonitorController ctrl,
      ChannelMonitor m, _MonAction a) async {
    final api = ref.read(adminMonitorApiProvider);
    try {
      switch (a) {
        case _MonAction.run:
          setState(() => _running = m.id);
          final results = await api.runNow(m.id);
          if (context.mounted) {
            final ok = results.where((r) => r.status == 'operational').length;
            showAppToast(
                context,
                context.tr('adminMonitor.runDone', params: {
                  'ok': '$ok',
                  'total': '${results.length}'
                }));
          }
        case _MonAction.toggle:
          await api.setEnabled(m.id, !m.enabled);
        case _MonAction.delete:
          final ok = await showConfirmDialog(
            context,
            title: context.tr('adminMonitor.delete'),
            message:
                context.tr('adminMonitor.deleteConfirm', params: {'name': m.name}),
            confirmLabel: context.tr('common.delete'),
            destructive: true,
          );
          if (!ok) return;
          await api.delete(m.id);
      }
      await ctrl.refresh();
      if (context.mounted && a != _MonAction.run) {
        showAppToast(context, context.tr('common.done'));
      }
    } catch (e) {
      if (context.mounted) showAppToast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _running = null);
    }
  }
}

class _MonitorCard extends StatelessWidget {
  const _MonitorCard({
    required this.monitor,
    required this.running,
    required this.onTap,
    required this.onAction,
  });
  final ChannelMonitor monitor;
  final bool running;
  final VoidCallback onTap;
  final ValueChanged<_MonAction> onAction;

  @override
  Widget build(BuildContext context) {
    final m = monitor;
    final scheme = Theme.of(context).colorScheme;
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
              Row(children: [
                Expanded(
                  child: Text(m.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                ),
                if (!m.enabled) ...[
                  StatusPill(
                      label: context.tr('adminMonitor.disabled'),
                      tone: StatusTone.neutral,
                      dense: true),
                  const SizedBox(width: 6),
                ],
                StatusPill(
                    label: context.tr(monitorStatusKey(m.primaryStatus)),
                    tone: monitorTone(m.primaryStatus),
                    dense: true),
                running
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : PopupMenuButton<_MonAction>(
                        icon: const Icon(Icons.more_vert, size: 20),
                        padding: EdgeInsets.zero,
                        onSelected: onAction,
                        itemBuilder: (context) => [
                          PopupMenuItem(
                              value: _MonAction.run,
                              height: 40,
                              child: Text(context.tr('adminMonitor.runNow'))),
                          PopupMenuItem(
                              value: _MonAction.toggle,
                              height: 40,
                              child: Text(context.tr(m.enabled
                                  ? 'adminMonitor.disable'
                                  : 'adminMonitor.enable'))),
                          PopupMenuItem(
                              value: _MonAction.delete,
                              height: 40,
                              child: Text(context.tr('adminMonitor.delete'),
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
                  _badge(context, m.provider, scheme.primaryContainer,
                      scheme.onPrimaryContainer),
                  const SizedBox(width: 6),
                  Flexible(
                      child: Text(m.primaryModel, overflow: TextOverflow.ellipsis)),
                  if (m.primaryLatencyMs != null) ...[
                    _dot(context),
                    Text('${m.primaryLatencyMs}ms'),
                  ],
                  _dot(context),
                  Text('7d ${m.availability7d.toStringAsFixed(1)}%'),
                  const SizedBox(width: 4),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
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
