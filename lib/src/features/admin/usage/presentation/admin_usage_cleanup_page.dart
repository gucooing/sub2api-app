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
import '../data/admin_usage_api.dart';
import '../providers/admin_usage_providers.dart';

/// 用量清理任务:列表(状态/范围/已删行数)+ 新建(按时间范围批量删除)+ 取消。
class AdminUsageCleanupPage extends ConsumerStatefulWidget {
  const AdminUsageCleanupPage({super.key});

  @override
  ConsumerState<AdminUsageCleanupPage> createState() =>
      _AdminUsageCleanupPageState();
}

class _AdminUsageCleanupPageState extends ConsumerState<AdminUsageCleanupPage> {
  final _scroll = ScrollController();
  final List<UsageCleanupTask> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;
  int _page = 1;
  int _total = 0;
  bool _hasMore = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
        _loadMore();
      }
    });
    _loadFirst();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadFirst() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref.read(adminUsageApiProvider).cleanupTasks(page: 1);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(res.items);
        _loading = false;
        _page = res.page;
        _total = res.total;
        _hasMore = res.page < res.pages;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final res =
          await ref.read(adminUsageApiProvider).cleanupTasks(page: _page + 1);
      if (!mounted) return;
      setState(() {
        _items.addAll(res.items);
        _loadingMore = false;
        _page = res.page;
        _hasMore = res.page < res.pages;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('adminUsage.cleanupTitle'))),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-admin-usage-cleanup',
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: Text(context.tr('adminUsage.cleanupCreate')),
      ),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _items.isEmpty) {
      return ErrorRetryView(error: _error!, onRetry: _loadFirst);
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadFirst,
        child: ListView(children: [
          const SizedBox(height: 120),
          EmptyState(
              icon: Icons.cleaning_services_outlined,
              message: context.tr('adminUsage.noCleanupTasks')),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadFirst,
      child: ResponsiveCenter(
        maxWidth: 900,
        child: ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 24),
          itemCount: _items.length + 1,
          itemBuilder: (context, i) {
            if (i == _items.length) {
              if (_loadingMore) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Center(
                  child: Text(
                    context.tr('adminUsage.total', params: {'n': '$_total'}),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              );
            }
            return _taskCard(context, _items[i]);
          },
        ),
      ),
    );
  }

  Widget _taskCard(BuildContext context, UsageCleanupTask t) {
    final scheme = Theme.of(context).colorScheme;
    final tone = switch (t.status) {
      'completed' => StatusTone.positive,
      'failed' => StatusTone.danger,
      'canceled' => StatusTone.neutral,
      _ => StatusTone.info,
    };
    String fmt(String? raw) {
      if (raw == null || raw.isEmpty) return '-';
      final d = DateTime.tryParse(raw);
      return d == null ? raw : formatDate(d.toLocal());
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text('#${t.id}  ${fmt(t.startTime)} ~ ${fmt(t.endTime)}',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ),
              StatusPill(
                  label: context.tr('adminUsage.cstatus_${t.status}'),
                  tone: tone,
                  dense: true),
              if (t.isActive)
                IconButton(
                  icon: Icon(Icons.cancel_outlined,
                      size: 20, color: scheme.error),
                  tooltip: context.tr('adminUsage.cancelTask'),
                  onPressed: () => _cancel(t),
                ),
            ]),
            const SizedBox(height: 2),
            Text(
              '${context.tr('adminUsage.deletedRows')}: ${formatInt(t.deletedRows)}'
              '${t.errorMessage != null && t.errorMessage!.isNotEmpty ? '  ·  ${t.errorMessage}' : ''}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancel(UsageCleanupTask t) async {
    final ok = await showConfirmDialog(
      context,
      title: context.tr('adminUsage.cancelTask'),
      message: context.tr('adminUsage.cancelTaskConfirm'),
      confirmLabel: context.tr('adminUsage.cancelTask'),
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(adminUsageApiProvider).cancelCleanupTask(t.id);
      await _loadFirst();
      if (mounted) showAppToast(context, context.tr('common.done'));
    } catch (e) {
      if (mounted) showAppToast(context, '$e', error: true);
    }
  }

  Future<void> _create() async {
    final now = DateTime.now();
    var range = DateTimeRange(
        start: now.subtract(const Duration(days: 90)),
        end: now.subtract(const Duration(days: 30)));
    final modelCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('adminUsage.cleanupCreate')),
        content: SizedBox(
          width: 360,
          child: StatefulBuilder(
            builder: (ctx, setS) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ctx.tr('adminUsage.cleanupHint'),
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: Theme.of(ctx).colorScheme.error)),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.date_range, size: 18),
                  label: Text(
                      '${formatDate(range.start)} ~ ${formatDate(range.end)}'),
                  onPressed: () async {
                    final r = await showDateRangePicker(
                      context: ctx,
                      firstDate: DateTime(2020),
                      lastDate: now,
                      initialDateRange: range,
                    );
                    if (r != null) setS(() => range = r);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: modelCtrl,
                  decoration: InputDecoration(
                    labelText: ctx.tr('adminUsage.fModel'),
                    helperText: ctx.tr('common.optional'),
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.tr('common.cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.tr('adminUsage.cleanupCreate'))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(adminUsageApiProvider).createCleanupTask(
            startDate: formatDate(range.start),
            endDate: formatDate(range.end),
            model: modelCtrl.text.trim(),
          );
      await _loadFirst();
      if (mounted) showAppToast(context, context.tr('common.done'));
    } catch (e) {
      if (mounted) showAppToast(context, '$e', error: true);
    }
  }
}
