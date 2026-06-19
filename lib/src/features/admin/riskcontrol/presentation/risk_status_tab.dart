import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../i18n/app_localizations.dart';
import '../../../../shared/format/formatters.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../../shared/widgets/error_retry.dart';
import '../../../../shared/widgets/progress_meter.dart';
import '../../../../shared/widgets/responsive.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../data/admin_risk_control_api.dart';
import '../providers/admin_risk_control_providers.dart';

StatusTone apiKeyTone(String status) => switch (status) {
      'ok' => StatusTone.positive,
      'error' => StatusTone.warning,
      'frozen' => StatusTone.danger,
      _ => StatusTone.neutral,
    };

/// 风控运行状态 Tab。
class RiskStatusTab extends ConsumerStatefulWidget {
  const RiskStatusTab({super.key});

  @override
  ConsumerState<RiskStatusTab> createState() => _RiskStatusTabState();
}

class _RiskStatusTabState extends ConsumerState<RiskStatusTab>
    with AutomaticKeepAliveClientMixin {
  final _hashCtrl = TextEditingController();
  bool _busy = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _hashCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final async = ref.watch(riskControlStatusProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorRetryView(
          error: e, onRetry: () => ref.invalidate(riskControlStatusProvider)),
      data: (s) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(riskControlStatusProvider),
        child: ResponsiveCenter(
          maxWidth: 1100,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 24),
            children: [
              _runtimeCard(context, s),
              const SizedBox(height: 10),
              _preBlockCard(context, s),
              const SizedBox(height: 10),
              if (s.apiKeyLoads.isNotEmpty) ...[
                _apiKeyLoadCard(context, s),
                const SizedBox(height: 10),
              ],
              _flaggedHashCard(context, s),
            ],
          ),
        ),
      ),
    );
  }

  Widget _runtimeCard(BuildContext context, ContentModerationStatus s) {
    return _card(
      context,
      title: context.tr('adminRisk.workerStatus'),
      trailing: StatusPill(
        label: s.enabled
            ? context.tr('adminRisk.mode_${s.mode}')
            : context.tr('adminRisk.disabled'),
        tone: s.enabled ? StatusTone.positive : StatusTone.neutral,
        dense: true,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(context.tr('adminRisk.queueUsage'),
                      style: Theme.of(context).textTheme.labelMedium),
                ),
                Text('${s.queueLength}/${s.queueSize}',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant)),
              ]),
              const SizedBox(height: 4),
              ProgressMeter(
                value: s.queueLength.toDouble(),
                max: s.queueSize.toDouble(),
              ),
            ],
          ),
        ),
        _metricsGrid(context, [
          (context.tr('adminRisk.activeWorkers'), '${s.activeWorkers}'),
          (context.tr('adminRisk.idleWorkers'), '${s.idleWorkers}'),
          (context.tr('adminRisk.workerPool'), '${s.workerCount}/${s.maxWorkers}'),
          (context.tr('adminRisk.processed'), formatCompact(s.processed)),
          (context.tr('adminRisk.enqueued'), formatCompact(s.enqueued)),
          ('${context.tr('adminRisk.dropped')}/${context.tr('adminRisk.errors')}',
              '${s.dropped}/${s.errors}'),
        ]),
      ],
    );
  }

  Widget _preBlockCard(BuildContext context, ContentModerationStatus s) {
    return _card(
      context,
      title: context.tr('adminRisk.preBlockStats'),
      children: [
        _metricsGrid(context, [
          (context.tr('adminRisk.preBlockChecked'), formatCompact(s.preBlockChecked)),
          (context.tr('adminRisk.preBlockAllowed'), formatCompact(s.preBlockAllowed)),
          (context.tr('adminRisk.preBlockBlocked'), formatCompact(s.preBlockBlocked)),
          (context.tr('adminRisk.preBlockErrors'), formatCompact(s.preBlockErrors)),
          (context.tr('adminRisk.avgLatency'),
              '${s.preBlockAvgLatencyMs.toStringAsFixed(0)} ms'),
        ]),
      ],
    );
  }

  Widget _apiKeyLoadCard(BuildContext context, ContentModerationStatus s) {
    final scheme = Theme.of(context).colorScheme;
    return _card(
      context,
      title: context.tr('adminRisk.apiKeyLoad'),
      children: [
        for (final k in s.apiKeyLoads)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              _statusDot(context, k.status),
              const SizedBox(width: 8),
              Expanded(
                child: Text(k.masked.isEmpty ? '-' : k.masked,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontFamily: 'monospace'),
                    overflow: TextOverflow.ellipsis),
              ),
              Text(
                  '${context.tr('adminRisk.keyActive')} ${k.active} · ${context.tr('adminRisk.keyTotal')} ${k.total} · ${k.avgLatencyMs.toStringAsFixed(0)}ms',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
            ]),
          ),
      ],
    );
  }

  Widget _flaggedHashCard(BuildContext context, ContentModerationStatus s) {
    final scheme = Theme.of(context).colorScheme;
    return _card(
      context,
      title: context.tr('adminRisk.flaggedHashes'),
      children: [
        Row(children: [
          Expanded(
            child: Text(
                context.tr('adminRisk.flaggedHashCount',
                    params: {'count': formatInt(s.flaggedHashCount)}),
                style: Theme.of(context).textTheme.bodyMedium),
          ),
          TextButton.icon(
            onPressed: (_busy || s.flaggedHashCount == 0)
                ? null
                : () => _clearHashes(context),
            icon: const Icon(Icons.delete_sweep_outlined, size: 18),
            label: Text(context.tr('adminRisk.clearFlaggedHashes')),
            style: TextButton.styleFrom(foregroundColor: scheme.error),
          ),
        ]),
        const SizedBox(height: 6),
        TextField(
          controller: _hashCtrl,
          decoration: InputDecoration(
            hintText: context.tr('adminRisk.flaggedHashHint'),
            isDense: true,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: context.tr('adminRisk.deleteFlaggedHash'),
              onPressed: _busy ? null : () => _deleteHash(context),
            ),
          ),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
        ),
        if (s.lastCleanupAt != null) ...[
          const SizedBox(height: 8),
          Text(
              context.tr('adminRisk.cleanupStats', params: {
                'hit': '${s.lastCleanupDeletedHit}',
                'nonHit': '${s.lastCleanupDeletedNonHit}'
              }),
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ],
    );
  }

  Future<void> _clearHashes(BuildContext context) async {
    final ok = await showConfirmDialog(
      context,
      title: context.tr('adminRisk.clearFlaggedHashes'),
      message: context.tr('adminRisk.clearFlaggedHashesConfirm'),
      confirmLabel: context.tr('common.delete'),
      destructive: true,
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      final n = await ref.read(adminRiskControlApiProvider).clearFlaggedHashes();
      ref.invalidate(riskControlStatusProvider);
      if (context.mounted) {
        showAppToast(
            context, context.tr('adminRisk.cleared', params: {'n': '$n'}));
      }
    } catch (e) {
      if (context.mounted) showAppToast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteHash(BuildContext context) async {
    final hash = _hashCtrl.text.trim();
    final valid = RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(hash);
    if (!valid) {
      showAppToast(context, context.tr('adminRisk.invalidHash'), error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(adminRiskControlApiProvider).deleteFlaggedHash(hash);
      ref.invalidate(riskControlStatusProvider);
      _hashCtrl.clear();
      if (context.mounted) showAppToast(context, context.tr('common.done'));
    } catch (e) {
      if (context.mounted) showAppToast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _statusDot(BuildContext context, String status) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (status) {
      'ok' => Colors.green,
      'error' => const Color(0xFFB7791F),
      'frozen' => scheme.error,
      _ => scheme.outline,
    };
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _metricsGrid(BuildContext context, List<(String, String)> cells) {
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 520 ? 3 : 2;
      final w = (c.maxWidth - (cols - 1) * 12) / cols;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final cell in cells)
            SizedBox(
              width: w,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cell.$1,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(cell.$2,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
        ],
      );
    });
  }

  Widget _card(BuildContext context,
      {required String title,
      required List<Widget> children,
      Widget? trailing}) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ),
              ?trailing,
            ]),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}

// 复制到剪贴板辅助(命中哈希等场景预留)。
Future<void> copyText(BuildContext context, String text, String toast) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) showAppToast(context, toast);
}
