import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../i18n/app_localizations.dart';
import '../../../../shared/format/formatters.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/responsive.dart';
import '../../../../shared/widgets/metric_trend_chart.dart';
import '../../../../shared/widgets/progress_meter.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../data/keys_api.dart';
import '../providers/keys_providers.dart';
import 'key_edit_sheet.dart';
import 'keys_tab.dart';

enum _Metric { cost, tokens }

/// 密钥详情页:每日用量趋势 + 滚动窗口 + 配额 + 基本信息 + 操作。
class KeyDetailPage extends ConsumerStatefulWidget {
  const KeyDetailPage({super.key, required this.keyId});

  final int keyId;

  @override
  ConsumerState<KeyDetailPage> createState() => _KeyDetailPageState();
}

class _KeyDetailPageState extends ConsumerState<KeyDetailPage> {
  _Metric _metric = _Metric.cost;

  @override
  Widget build(BuildContext context) {
    final keys = ref.watch(keysListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('keys.detail')),
      ),
      body: ResponsiveCenter(
        maxWidth: 840,
        child: AsyncValueView(
        value: keys,
        onRetry: () => ref.invalidate(keysListProvider),
        builder: (context, list) {
          final info = list.where((k) => k.id == widget.keyId).firstOrNull;
          if (info == null) {
            return EmptyState(
              icon: Icons.vpn_key_off_outlined,
              message: context.tr('common.empty'),
            );
          }
          return _Body(
            info: info,
            metric: _metric,
            onMetric: (m) => setState(() => _metric = m),
          );
        },
      ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.info,
    required this.metric,
    required this.onMetric,
  });

  final ApiKeyInfo info;
  final _Metric metric;
  final ValueChanged<_Metric> onMetric;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final daily = ref.watch(keyDailyUsageProvider(info.id));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 标题 + 状态 + 倍率
        Row(
          children: [
            Expanded(
              child: Text(
                info.name,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            StatusPill(
              label: keyStatusLabel(context, info.status),
              tone: keyStatusTone(info.status),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 完整密钥(可复制)
        Card(
          child: InkWell(
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: info.key));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.tr('common.copied'))),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      info.key,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 12.5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.copy, size: 18, color: scheme.primary),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        // 每日用量趋势
        SectionHeader(
          title: context.tr('keys.dailyUsage'),
          trailing: SegmentedButton<_Metric>(
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: [
              ButtonSegment(
                  value: _Metric.cost, label: Text(context.tr('dashboard.cost'))),
              ButtonSegment(
                  value: _Metric.tokens,
                  label: Text(context.tr('dashboard.tokens'))),
            ],
            selected: {metric},
            onSelectionChanged: (s) => onMetric(s.first),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
            child: SizedBox(
              height: 200,
              child: AsyncValueView(
                value: daily,
                onRetry: () => ref.invalidate(keyDailyUsageProvider(info.id)),
                builder: (context, points) => MetricTrendChart(
                  points: [
                    for (final p in points)
                      TrendChartPoint(
                        label: p.shortLabel,
                        value: metric == _Metric.cost
                            ? p.actualCost
                            : p.totalTokens.toDouble(),
                      ),
                  ],
                  color: metric == _Metric.cost
                      ? scheme.primary
                      : AppColors.brandGreen,
                  valueLabel: (v) => metric == _Metric.cost
                      ? formatCost(v)
                      : formatCompact(v.round()),
                  emptyHint: context.tr('keys.noUsageData'),
                ),
              ),
            ),
          ),
        ),
        // 滚动窗口
        if (info.hasWindowLimits) ...[
          const SizedBox(height: 20),
          SectionHeader(title: context.tr('keys.windows')),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Column(
                children: [
                  if (info.rateLimit5h > 0)
                    _WindowRow(
                        label: '5h',
                        used: info.usage5h,
                        limit: info.rateLimit5h),
                  if (info.rateLimit1d > 0)
                    _WindowRow(
                        label: '1d',
                        used: info.usage1d,
                        limit: info.rateLimit1d),
                  if (info.rateLimit7d > 0)
                    _WindowRow(
                        label: '7d',
                        used: info.usage7d,
                        limit: info.rateLimit7d),
                ],
              ),
            ),
          ),
        ],
        // 配额
        if (info.quota > 0) ...[
          const SizedBox(height: 20),
          SectionHeader(title: context.tr('keys.quota')),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(formatCost(info.quotaUsed),
                          style: Theme.of(context).textTheme.titleMedium),
                      Text(' / ${formatCost(info.quota)}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ProgressMeter(
                      value: info.quotaUsed, max: info.quota, height: 8),
                ],
              ),
            ),
          ),
        ],
        // 基本信息
        const SizedBox(height: 20),
        SectionHeader(title: context.tr('keys.overview')),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              children: [
                if (info.groupName != null)
                  _InfoRow(
                      label: context.tr('keys.group'), value: info.groupName!),
                if (info.rateMultiplier != null)
                  _InfoRow(
                    label: context.tr('keys.rate'),
                    value:
                        '×${info.rateMultiplier!.toStringAsFixed(info.rateMultiplier!.truncateToDouble() == info.rateMultiplier ? 0 : 2)}',
                  ),
                if (info.createdAt != null)
                  _InfoRow(
                      label: context.tr('keys.created'),
                      value: formatDate(info.createdAt!)),
                _InfoRow(
                  label: context.tr('keys.expires'),
                  value: info.expiresAt != null
                      ? formatDate(info.expiresAt!)
                      : context.tr('keys.unlimited'),
                ),
                _InfoRow(
                  label: context.tr('keys.lastUsed'),
                  value: info.lastUsedAt != null
                      ? formatDateTime(info.lastUsedAt!)
                      : context.tr('keys.neverUsed'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        // 操作
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => showKeyEditSheet(context, ref, existing: info),
                icon: const Icon(Icons.edit_outlined),
                label: Text(context.tr('common.edit')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _toggle(context, ref),
                icon: Icon(info.isActive
                    ? Icons.pause_circle_outline
                    : Icons.play_circle_outline),
                label: Text(info.isActive
                    ? context.tr('keys.disable')
                    : context.tr('keys.enable')),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () => _confirmDelete(context, ref),
          icon: Icon(Icons.delete_outline, color: scheme.error),
          label: Text(context.tr('common.delete'),
              style: TextStyle(color: scheme.error)),
        ),
      ],
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(keysApiProvider).update(
            info.id,
            status: info.isActive ? 'inactive' : 'active',
          );
      ref.invalidate(keysListProvider);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.localizedMessage(context))),
        );
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: context.tr('common.delete'),
      message: context.tr('keys.deleteConfirm', params: {'name': info.name}),
      confirmLabel: context.tr('common.delete'),
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await ref.read(keysApiProvider).remove(info.id);
      ref.invalidate(keysListProvider);
      if (context.mounted) context.pop();
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.localizedMessage(context))),
        );
      }
    }
  }
}

class _WindowRow extends StatelessWidget {
  const _WindowRow({required this.label, required this.used, required this.limit});

  final String label;
  final double used;
  final double limit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 32,
                child: Text(label,
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ),
              const Spacer(),
              Text('${formatCost(used)} / ${formatCost(limit)}',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 5),
          ProgressMeter(value: used, max: limit),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Text(label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const Spacer(),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
