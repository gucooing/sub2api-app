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
import '../data/admin_proxies_api.dart';
import '../providers/admin_proxies_providers.dart';

enum _Action { test, quality, edit, toggle, delete }

const _protocols = ['', 'http', 'https', 'socks5', 'socks5h'];
const _statuses = ['', 'active', 'inactive', 'expired'];

/// 代理IP管理:列表 + 协议/状态筛选 + 搜索 + 新增/编辑/删除/启停 + 连通性测试 + 质量检测。
class ProxyListPage extends ConsumerStatefulWidget {
  const ProxyListPage({super.key});

  @override
  ConsumerState<ProxyListPage> createState() => _ProxyListPageState();
}

class _ProxyListPageState extends ConsumerState<ProxyListPage> {
  final _scroll = ScrollController();
  final _searchCtrl = TextEditingController();
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
        ref.read(adminProxiesControllerProvider.notifier).loadMore();
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
    final state = ref.watch(adminProxiesControllerProvider);
    final ctrl = ref.read(adminProxiesControllerProvider.notifier);
    final filterBtn = IconButton.filledTonal(
      onPressed: () => _openFilters(context, state, ctrl),
      tooltip: context.tr('adminProxies.filters'),
      icon: const Icon(Icons.tune),
    );
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('adminProxies.title'))),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-admin-proxies',
        onPressed: () async {
          await context.push('/admin/proxies/new');
          ref.invalidate(adminProxiesAllListProvider);
          ctrl.refresh();
        },
        icon: const Icon(Icons.add),
        label: Text(context.tr('adminProxies.create')),
      ),
      body: Column(
        children: [
          ResponsiveCenter(
            maxWidth: 1100,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onSubmitted: ctrl.setSearch,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: context.tr('adminProxies.searchHint'),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: const OutlineInputBorder(),
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

  Widget _body(BuildContext context, AdminProxiesState state,
      AdminProxiesController ctrl) {
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
              icon: Icons.dns_outlined,
              message: context.tr('adminProxies.empty')),
        ]),
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
                    context.tr('adminProxies.total',
                        params: {'n': '${state.total}'}),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              );
            }
            return _ProxyCard(
              proxy: state.items[i],
              busy: _busy.contains(state.items[i].id),
              onAction: (a) => _runAction(context, ctrl, state.items[i], a),
            );
          },
        ),
      ),
    );
  }

  Future<void> _runAction(BuildContext context, AdminProxiesController ctrl,
      Proxy p, _Action a) async {
    final api = ref.read(adminProxiesApiProvider);
    switch (a) {
      case _Action.test:
        setState(() => _busy.add(p.id));
        try {
          final r = await api.test(p.id);
          if (context.mounted) _showTestResult(context, r);
        } catch (e) {
          if (context.mounted) showAppToast(context, '$e', error: true);
        } finally {
          if (mounted) setState(() => _busy.remove(p.id));
        }
      case _Action.quality:
        setState(() => _busy.add(p.id));
        try {
          final r = await api.qualityCheck(p.id);
          if (context.mounted) _showQuality(context, r);
        } catch (e) {
          if (context.mounted) showAppToast(context, '$e', error: true);
        } finally {
          if (mounted) setState(() => _busy.remove(p.id));
        }
      case _Action.edit:
        await context.push('/admin/proxies/${p.id}/edit', extra: p);
        ref.invalidate(adminProxiesAllListProvider);
        ctrl.refresh();
      case _Action.toggle:
        try {
          await api.setStatus(p.id, p.status != 'active');
          await ctrl.refresh();
          if (context.mounted) showAppToast(context, context.tr('common.done'));
        } catch (e) {
          if (context.mounted) showAppToast(context, '$e', error: true);
        }
      case _Action.delete:
        final ok = await showConfirmDialog(
          context,
          title: context.tr('adminProxies.delete'),
          message: context.tr('adminProxies.deleteConfirm'),
          confirmLabel: context.tr('common.delete'),
          destructive: true,
        );
        if (!ok) return;
        try {
          await api.delete(p.id);
          await ctrl.refresh();
          if (context.mounted) showAppToast(context, context.tr('common.done'));
        } catch (e) {
          if (context.mounted) showAppToast(context, '$e', error: true);
        }
    }
  }

  void _showTestResult(BuildContext context, ProxyTestResult r) {
    final loc =
        [r.city, r.region, r.country].where((e) => (e ?? '').isNotEmpty).join(', ');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr(r.success
            ? 'adminProxies.testOk'
            : 'adminProxies.testFail')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (r.message.isNotEmpty) Text(r.message),
            if (r.latencyMs != null)
              Text('${ctx.tr('adminProxies.latency')}: ${r.latencyMs!.toStringAsFixed(0)} ms'),
            if (r.ipAddress != null)
              Text('IP: ${r.ipAddress}'),
            if (loc.isNotEmpty) Text('${ctx.tr('adminProxies.location')}: $loc'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(ctx.tr('common.close'))),
        ],
      ),
    );
  }

  void _showQuality(BuildContext context, ProxyQualityResult r) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.95,
        builder: (ctx, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Row(children: [
              Text('${ctx.tr('adminProxies.quality')} · ${r.grade}',
                  style: Theme.of(ctx)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('${r.score}',
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Theme.of(ctx).colorScheme.primary)),
            ]),
            if (r.summary.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(r.summary,
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
            ],
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 4, children: [
              if (r.exitIp != null) _chip(ctx, 'IP', r.exitIp!),
              if (r.country != null) _chip(ctx, ctx.tr('adminProxies.country'), r.country!),
              if (r.baseLatencyMs != null)
                _chip(ctx, ctx.tr('adminProxies.latency'),
                    '${r.baseLatencyMs!.toStringAsFixed(0)}ms'),
              _chip(ctx, ctx.tr('adminProxies.qPass'), '${r.passedCount}'),
              _chip(ctx, ctx.tr('adminProxies.qWarn'), '${r.warnCount}'),
              _chip(ctx, ctx.tr('adminProxies.qFail'), '${r.failedCount}'),
              _chip(ctx, ctx.tr('adminProxies.qChallenge'), '${r.challengeCount}'),
            ]),
            const Divider(height: 24),
            for (final it in r.items)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  switch (it.status) {
                    'pass' => Icons.check_circle,
                    'warn' => Icons.warning_amber,
                    'challenge' => Icons.shield_outlined,
                    _ => Icons.cancel,
                  },
                  size: 20,
                  color: switch (it.status) {
                    'pass' => Theme.of(ctx).colorScheme.primary,
                    'warn' => const Color(0xFFB7791F),
                    _ => Theme.of(ctx).colorScheme.error,
                  },
                ),
                title: Text(it.target, overflow: TextOverflow.ellipsis),
                subtitle: Text([
                  if (it.httpStatus != null) 'HTTP ${it.httpStatus}',
                  if (it.latencyMs != null)
                    '${it.latencyMs!.toStringAsFixed(0)}ms',
                  if ((it.message ?? '').isNotEmpty) it.message!,
                ].join(' · ')),
              ),
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String k, String v) => Chip(
        visualDensity: VisualDensity.compact,
        label: Text('$k: $v', style: Theme.of(context).textTheme.labelSmall),
      );

  Future<void> _openFilters(BuildContext context, AdminProxiesState state,
      AdminProxiesController ctrl) async {
    var protocol = state.protocol;
    var status = state.status;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ctx.tr('adminProxies.protocol'),
                  style: Theme.of(ctx).textTheme.labelLarge),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4, children: [
                for (final p in _protocols)
                  ChoiceChip(
                    label: Text(p.isEmpty
                        ? ctx.tr('adminProxies.all')
                        : p.toUpperCase()),
                    selected: protocol == p,
                    onSelected: (_) => setS(() => protocol = p),
                  ),
              ]),
              const SizedBox(height: 14),
              Text(ctx.tr('adminProxies.status'),
                  style: Theme.of(ctx).textTheme.labelLarge),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4, children: [
                for (final s in _statuses)
                  ChoiceChip(
                    label: Text(s.isEmpty
                        ? ctx.tr('adminProxies.all')
                        : ctx.tr('adminProxies.status_$s')),
                    selected: status == s,
                    onSelected: (_) => setS(() => status = s),
                  ),
              ]),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      protocol = '';
                      status = '';
                      Navigator.pop(ctx, true);
                    },
                    child: Text(ctx.tr('adminProxies.reset')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(ctx.tr('adminProxies.apply')),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
    if (ok == true) ctrl.applyFilters(protocol: protocol, status: status);
  }
}

class _ProxyCard extends StatelessWidget {
  const _ProxyCard(
      {required this.proxy, required this.busy, required this.onAction});
  final Proxy proxy;
  final bool busy;
  final ValueChanged<_Action> onAction;

  StatusTone get _tone => switch (proxy.status) {
        'active' => StatusTone.positive,
        'expired' => StatusTone.danger,
        _ => StatusTone.neutral,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = proxy.status == 'active';
    final meta = <String>[
      if (proxy.latencyMs != null) '${proxy.latencyMs!.toStringAsFixed(0)}ms',
      if (proxy.location.isNotEmpty) proxy.location,
      if (proxy.accountCount != null)
        context.tr('adminProxies.accounts', params: {'n': '${proxy.accountCount}'}),
      if ((proxy.qualityGrade ?? '').isNotEmpty)
        '${context.tr('adminProxies.quality')} ${proxy.qualityGrade}',
    ].join('  ·  ');
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(proxy.name.isEmpty ? proxy.endpoint : proxy.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
              ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              StatusPill(
                  label: context.tr('adminProxies.status_${proxy.status}'),
                  tone: _tone,
                  dense: true),
              PopupMenuButton<_Action>(
                icon: const Icon(Icons.more_vert, size: 20),
                padding: EdgeInsets.zero,
                onSelected: onAction,
                itemBuilder: (context) => [
                  PopupMenuItem(
                      value: _Action.test,
                      height: 40,
                      child: Text(context.tr('adminProxies.test'))),
                  PopupMenuItem(
                      value: _Action.quality,
                      height: 40,
                      child: Text(context.tr('adminProxies.qualityCheck'))),
                  PopupMenuItem(
                      value: _Action.edit,
                      height: 40,
                      child: Text(context.tr('common.edit'))),
                  PopupMenuItem(
                      value: _Action.toggle,
                      height: 40,
                      child: Text(context.tr(
                          active ? 'adminProxies.disable' : 'adminProxies.enable'))),
                  PopupMenuItem(
                      value: _Action.delete,
                      height: 40,
                      child: Text(context.tr('common.delete'),
                          style: TextStyle(color: scheme.error))),
                ],
              ),
            ]),
            Text(proxy.endpoint,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace', color: scheme.onSurfaceVariant),
                overflow: TextOverflow.ellipsis),
            if (meta.isNotEmpty)
              Text(meta,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
