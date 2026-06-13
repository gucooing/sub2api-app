import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../i18n/app_localizations.dart';
import '../../../../shared/format/formatters.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../../../../shared/widgets/token_composition.dart';
import '../data/usage_logs_api.dart';
import '../providers/usage_logs_providers.dart';

StatusTone logStatusTone(String? status) => switch (status) {
      'success' => StatusTone.positive,
      'error' => StatusTone.danger,
      _ => StatusTone.neutral,
    };

/// 使用记录详情页(沉浸式,含每请求 token 构成与缓存)。
class LogDetailPage extends ConsumerWidget {
  const LogDetailPage({super.key, required this.logId});

  final int logId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.watch(usageLogDetailProvider(logId));

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('usage.recordDetail'))),
      body: AsyncValueView(
        value: log,
        onRetry: () => ref.invalidate(usageLogDetailProvider(logId)),
        builder: (context, l) => _Body(log: l),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.log});

  final UsageLog log;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                log.model,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (log.status != null)
              StatusPill(
                label: log.status!,
                tone: logStatusTone(log.status),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(log.provider,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                )),
        const SizedBox(height: 16),
        // 消耗
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _BigStat(
                    label: context.tr('usage.actualCost'),
                    value: formatCost(log.actualCost ?? 0, decimals: 6),
                    color: scheme.primary,
                  ),
                ),
                Expanded(
                  child: _BigStat(
                    label: context.tr('usage.standardCost'),
                    value: formatCost(log.cost ?? 0, decimals: 6),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Token 构成
        SectionHeader(
          title: context.tr('tokens.composition'),
          trailing: Text(
            formatCompact(log.totalTokens ?? 0),
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TokenComposition(
              segments: [
                TokenSegment(
                    label: context.tr('tokens.input'),
                    value: log.inputTokens ?? 0,
                    color: AppColors.brandBlue),
                TokenSegment(
                    label: context.tr('tokens.output'),
                    value: log.outputTokens ?? 0,
                    color: AppColors.brandGreen),
                TokenSegment(
                    label: context.tr('tokens.cacheCreation'),
                    value: log.cacheCreationTokens ?? 0,
                    color: const Color(0xFFF59E0B)),
                TokenSegment(
                    label: context.tr('tokens.cacheRead'),
                    value: log.cacheReadTokens ?? 0,
                    color: const Color(0xFF8B5CF6)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        SectionHeader(title: context.tr('keys.overview')),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              children: [
                if (log.createdAt != null)
                  _InfoRow(
                      label: context.tr('usage.time'),
                      value: formatDateTime(log.createdAt!)),
                if (log.durationMs != null)
                  _InfoRow(
                      label: context.tr('usage.duration'),
                      value: '${log.durationMs}ms'),
                if (log.apiKeyName != null)
                  _InfoRow(
                      label: context.tr('nav.keys'), value: log.apiKeyName!),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BigStat extends StatelessWidget {
  const _BigStat({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color,
                  )),
        ),
      ],
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
