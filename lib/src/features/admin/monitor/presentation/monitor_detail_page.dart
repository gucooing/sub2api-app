import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../i18n/app_localizations.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../shared/widgets/error_retry.dart';
import '../../../../shared/widgets/responsive.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../data/admin_monitor_api.dart';
import '../providers/admin_monitor_providers.dart';
import 'monitor_list_page.dart' show monitorTone, monitorStatusKey;

/// 渠道监控详情:概览 + 各模型最新状态 + 立即检测 + 检测历史。
class MonitorDetailPage extends ConsumerStatefulWidget {
  const MonitorDetailPage({super.key, required this.monitorId});
  final int monitorId;

  @override
  ConsumerState<MonitorDetailPage> createState() => _MonitorDetailPageState();
}

class _MonitorDetailPageState extends ConsumerState<MonitorDetailPage> {
  bool _running = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(adminMonitorDetailProvider(widget.monitorId));
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('adminMonitor.detailTitle'))),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorRetryView(
          error: e,
          onRetry: () =>
              ref.invalidate(adminMonitorDetailProvider(widget.monitorId)),
        ),
        data: (m) => _content(context, m),
      ),
    );
  }

  Future<void> _run() async {
    if (_running) return;
    setState(() => _running = true);
    try {
      final results =
          await ref.read(adminMonitorApiProvider).runNow(widget.monitorId);
      ref.invalidate(adminMonitorDetailProvider(widget.monitorId));
      ref.invalidate(adminMonitorHistoryProvider(widget.monitorId));
      if (mounted) {
        final ok = results.where((r) => r.status == 'operational').length;
        showAppToast(
            context,
            context.tr('adminMonitor.runDone',
                params: {'ok': '$ok', 'total': '${results.length}'}));
      }
    } catch (e) {
      if (mounted) showAppToast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Widget _content(BuildContext context, ChannelMonitor m) {
    return ResponsiveCenter(
      maxWidth: 720,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(children: [
            Expanded(
              child: Text(m.name,
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            StatusPill(
              label: context.tr(monitorStatusKey(m.primaryStatus)),
              tone: monitorTone(m.primaryStatus),
            ),
          ]),
          const SizedBox(height: 4),
          if (m.apiKeyDecryptFailed)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .errorContainer
                    .withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(context.tr('adminMonitor.decryptFailed'),
                  style: Theme.of(context).textTheme.bodySmall),
            ),

          const SizedBox(height: 8),
          SectionHeader(title: context.tr('adminMonitor.sec.info')),
          _kv(context, 'adminMonitor.kProvider', m.provider),
          _kv(context, 'adminMonitor.kPrimary', m.primaryModel),
          _kv(context, 'adminMonitor.kEndpoint', m.endpoint),
          _kv(context, 'adminMonitor.kInterval', '${m.intervalSeconds}s'),
          _kv(context, 'adminMonitor.kAvailability',
              '${m.availability7d.toStringAsFixed(1)}%'),
          if (m.primaryLatencyMs != null)
            _kv(context, 'adminMonitor.kLatency', '${m.primaryLatencyMs}ms'),
          if (m.groupName.isNotEmpty)
            _kv(context, 'adminMonitor.kGroup', m.groupName),
          if (m.lastCheckedAt != null)
            _kv(context, 'adminMonitor.kLastChecked', m.lastCheckedAt!),

          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: _running ? null : _run,
            icon: _running
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.play_arrow, size: 18),
            label: Text(context.tr('adminMonitor.runNow')),
          ),

          if (m.extraModelsStatus.isNotEmpty) ...[
            const SizedBox(height: 16),
            SectionHeader(title: context.tr('adminMonitor.sec.models')),
            for (final e in m.extraModelsStatus)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(e.model),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (e.latencyMs != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text('${e.latencyMs}ms',
                          style: Theme.of(context).textTheme.bodySmall),
                    ),
                  StatusPill(
                      label: context.tr(monitorStatusKey(e.status)),
                      tone: monitorTone(e.status),
                      dense: true),
                ]),
              ),
          ],

          const SizedBox(height: 16),
          SectionHeader(title: context.tr('adminMonitor.sec.history')),
          _history(context),
        ],
      ),
    );
  }

  Widget _history(BuildContext context) {
    final async = ref.watch(adminMonitorHistoryProvider(widget.monitorId));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Text('$e',
          style: TextStyle(color: Theme.of(context).colorScheme.error)),
      data: (items) {
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Text(context.tr('adminMonitor.noHistory'),
                style: Theme.of(context).textTheme.bodySmall),
          );
        }
        return Column(
          children: [
            for (final h in items)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.circle,
                    size: 12,
                    color: _toneColor(context, monitorTone(h.status))),
                title: Text(h.model),
                subtitle: Text(
                    '${h.checkedAt ?? ''}${h.message.isNotEmpty ? ' · ${h.message}' : ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                trailing: h.latencyMs != null
                    ? Text('${h.latencyMs}ms',
                        style: Theme.of(context).textTheme.bodySmall)
                    : null,
              ),
          ],
        );
      },
    );
  }

  Color _toneColor(BuildContext context, StatusTone tone) {
    final scheme = Theme.of(context).colorScheme;
    return switch (tone) {
      StatusTone.positive => const Color(0xFF4ADE80),
      StatusTone.warning => const Color(0xFFB7791F),
      StatusTone.danger => scheme.error,
      _ => scheme.onSurfaceVariant,
    };
  }

  Widget _kv(BuildContext context, String labelKey, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(context.tr(labelKey),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(value,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}
