import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../i18n/app_localizations.dart';
import '../../../../shared/format/formatters.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../../shared/widgets/error_retry.dart';
import '../../../../shared/widgets/responsive.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../data/admin_ops_api.dart';
import '../providers/admin_ops_providers.dart';
import 'ops_errors_tab.dart' show severityTone;

/// 运维告警 Tab:告警事件 + 告警规则。
class OpsAlertsTab extends ConsumerWidget {
  const OpsAlertsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(opsAlertEventsProvider);
    final rules = ref.watch(opsAlertRulesProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(opsAlertEventsProvider);
        ref.invalidate(opsAlertRulesProvider);
      },
      child: ResponsiveCenter(
        maxWidth: 1100,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 24),
          children: [
            _header(context, 'adminOps.alertEvents'),
            events.when(
              loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator())),
              error: (e, _) => ErrorRetryView(
                  error: e,
                  onRetry: () => ref.invalidate(opsAlertEventsProvider)),
              data: (list) => list.isEmpty
                  ? _empty(context, 'adminOps.noEvents')
                  : Column(
                      children: [
                        for (final ev in list)
                          _EventCard(
                            event: ev,
                            onResolve: () => _resolveEvent(context, ref, ev),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            _header(context, 'adminOps.alertRules'),
            rules.when(
              loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator())),
              error: (e, _) => ErrorRetryView(
                  error: e,
                  onRetry: () => ref.invalidate(opsAlertRulesProvider)),
              data: (list) => list.isEmpty
                  ? _empty(context, 'adminOps.noRules')
                  : Column(
                      children: [
                        for (final r in list)
                          _RuleCard(
                            rule: r,
                            onToggle: (v) => _toggleRule(context, ref, r, v),
                            onDelete: () => _deleteRule(context, ref, r),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, String key) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 4, 2, 6),
        child: Text(context.tr(key),
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
      );

  Widget _empty(BuildContext context, String key) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(context.tr(key),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
      );

  Future<void> _resolveEvent(
      BuildContext context, WidgetRef ref, AlertEvent ev) async {
    try {
      await ref.read(adminOpsApiProvider).resolveAlertEvent(ev.id);
      ref.invalidate(opsAlertEventsProvider);
      if (context.mounted) showAppToast(context, context.tr('adminOps.resolved'));
    } catch (e) {
      if (context.mounted) showAppToast(context, '$e', error: true);
    }
  }

  Future<void> _toggleRule(
      BuildContext context, WidgetRef ref, AlertRule r, bool v) async {
    try {
      await ref.read(adminOpsApiProvider).setAlertRuleEnabled(r.id, v);
      ref.invalidate(opsAlertRulesProvider);
    } catch (e) {
      if (context.mounted) showAppToast(context, '$e', error: true);
    }
  }

  Future<void> _deleteRule(
      BuildContext context, WidgetRef ref, AlertRule r) async {
    final ok = await showConfirmDialog(
      context,
      title: context.tr('adminOps.deleteRule'),
      message: context.tr('adminOps.deleteRuleConfirm'),
      confirmLabel: context.tr('common.delete'),
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(adminOpsApiProvider).deleteAlertRule(r.id);
      ref.invalidate(opsAlertRulesProvider);
      if (context.mounted) showAppToast(context, context.tr('common.done'));
    } catch (e) {
      if (context.mounted) showAppToast(context, '$e', error: true);
    }
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, required this.onResolve});
  final AlertEvent event;
  final VoidCallback onResolve;

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
                  label: event.severity,
                  tone: severityTone(event.severity),
                  dense: true),
              const SizedBox(width: 6),
              StatusPill(
                  label: context.tr('adminOps.alertStatus_${event.status}'),
                  tone:
                      event.isFiring ? StatusTone.danger : StatusTone.positive,
                  dense: true),
              const Spacer(),
              Text(_fmt(event.firedAt), style: muted),
            ]),
            const SizedBox(height: 4),
            Text(event.title?.isNotEmpty == true
                ? event.title!
                : '#${event.ruleId}',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w500)),
            if (event.description?.isNotEmpty == true)
              Text(event.description!, style: muted),
            const SizedBox(height: 2),
            Row(children: [
              if (event.metricValue != null && event.thresholdValue != null)
                Expanded(
                  child: Text(
                      '${context.tr('adminOps.metricValue')} ${event.metricValue} · ${context.tr('adminOps.thresholdValue')} ${event.thresholdValue}',
                      style: muted),
                )
              else
                const Spacer(),
              if (event.isFiring)
                TextButton.icon(
                  onPressed: onResolve,
                  icon: const Icon(Icons.check, size: 16),
                  label: Text(context.tr('adminOps.resolveEvent')),
                  style:
                      TextButton.styleFrom(visualDensity: VisualDensity.compact),
                ),
            ]),
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

class _RuleCard extends StatelessWidget {
  const _RuleCard(
      {required this.rule, required this.onToggle, required this.onDelete});
  final AlertRule rule;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

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
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(rule.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
              ),
              StatusPill(
                  label: rule.severity,
                  tone: severityTone(rule.severity),
                  dense: true),
              Switch(value: rule.enabled, onChanged: onToggle),
              IconButton(
                icon: Icon(Icons.delete_outline, size: 20, color: scheme.error),
                onPressed: onDelete,
                tooltip: context.tr('common.delete'),
              ),
            ]),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Wrap(spacing: 8, runSpacing: 2, children: [
                Text('${rule.metricType} ${rule.operator} ${rule.threshold}',
                    style: muted?.copyWith(fontFamily: 'monospace')),
                Text('·', style: muted),
                Text(
                    '${context.tr('adminOps.window')} ${rule.windowMinutes}m',
                    style: muted),
                if (rule.notifyEmail) ...[
                  Text('·', style: muted),
                  Text(context.tr('adminOps.notifyEmail'), style: muted),
                ],
                if (rule.lastTriggeredAt != null) ...[
                  Text('·', style: muted),
                  Text(
                      '${context.tr('adminOps.lastTriggered')} ${_fmt(rule.lastTriggeredAt!)}',
                      style: muted),
                ],
              ]),
            ),
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
