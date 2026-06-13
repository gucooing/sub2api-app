import 'dart:convert';

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
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (log.status != null)
              StatusPill(label: log.status!, tone: logStatusTone(log.status)),
          ],
        ),
        if (log.provider.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            log.provider,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: 16),
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
                    value: formatCost(log.standardCost ?? 0, decimals: 6),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        SectionHeader(title: context.tr('usage.requestInfo')),
        _DetailCard(
          children: [
            _InfoRow(label: 'ID', value: '${log.id}'),
            if (log.requestId != null)
              _InfoRow(
                label: context.tr('usage.requestId'),
                value: log.requestId!,
                monospace: true,
              ),
            if (log.createdAt != null)
              _InfoRow(
                label: context.tr('usage.time'),
                value: formatDateTime(log.createdAt!),
              ),
            if (log.durationMs != null)
              _InfoRow(
                label: context.tr('usage.duration'),
                value: '${log.durationMs}ms',
              ),
            if (log.firstTokenMs != null)
              _InfoRow(
                label: context.tr('usage.firstToken'),
                value: '${log.firstTokenMs}ms',
              ),
            if (log.requestType != null)
              _InfoRow(
                label: context.tr('usage.requestType'),
                value: log.requestType!,
              ),
            if (log.stream != null)
              _InfoRow(
                label: context.tr('usage.stream'),
                value: log.stream!
                    ? context.tr('usage.streamYes')
                    : context.tr('usage.streamNo'),
              ),
            if (log.openAIWSMode != null)
              _InfoRow(
                label: context.tr('usage.openaiWsMode'),
                value: _formatBool(log.openAIWSMode!),
              ),
            if (log.inboundEndpoint != null)
              _InfoRow(
                label: context.tr('usage.inboundEndpoint'),
                value: log.inboundEndpoint!,
                monospace: true,
              ),
            if (log.upstreamEndpoint != null)
              _InfoRow(
                label: context.tr('usage.upstreamEndpoint'),
                value: log.upstreamEndpoint!,
                monospace: true,
              ),
            if (log.serviceTier != null)
              _InfoRow(
                label: context.tr('usage.serviceTier'),
                value: log.serviceTier!,
              ),
            if (log.reasoningEffort != null)
              _InfoRow(
                label: context.tr('usage.reasoningEffort'),
                value: log.reasoningEffort!,
              ),
            if (log.userAgent != null)
              _InfoRow(
                label: context.tr('usage.userAgent'),
                value: log.userAgent!,
                monospace: true,
              ),
          ],
        ),
        const SizedBox(height: 20),
        SectionHeader(
          title: context.tr('tokens.composition'),
          trailing: Text(
            formatCompact(log.totalTokenCount),
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
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
                  color: AppColors.brandBlue,
                ),
                TokenSegment(
                  label: context.tr('tokens.output'),
                  value: log.outputTokens ?? 0,
                  color: AppColors.brandGreen,
                ),
                TokenSegment(
                  label: context.tr('tokens.cacheCreation'),
                  value: log.cacheCreationTokens ?? 0,
                  color: const Color(0xFFF59E0B),
                ),
                TokenSegment(
                  label: context.tr('tokens.cacheRead'),
                  value: log.cacheReadTokens ?? 0,
                  color: const Color(0xFF8B5CF6),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        _DetailCard(
          children: [
            _InfoRow(
              label: context.tr('usageLogs.inputTokens'),
              value: formatInt(log.inputTokens ?? 0),
            ),
            _InfoRow(
              label: context.tr('usageLogs.outputTokens'),
              value: formatInt(log.outputTokens ?? 0),
            ),
            _InfoRow(
              label: context.tr('usageLogs.cacheCreationTokens'),
              value: formatInt(log.cacheCreationTokens ?? 0),
            ),
            _InfoRow(
              label: context.tr('usageLogs.cacheReadTokens'),
              value: formatInt(log.cacheReadTokens ?? 0),
            ),
            if (log.cacheCreation5mTokens != null)
              _InfoRow(
                label: context.tr('usage.cacheCreation5m'),
                value: formatInt(log.cacheCreation5mTokens!),
              ),
            if (log.cacheCreation1hTokens != null)
              _InfoRow(
                label: context.tr('usage.cacheCreation1h'),
                value: formatInt(log.cacheCreation1hTokens!),
              ),
            if (log.imageOutputTokens != null && log.imageOutputTokens! > 0)
              _InfoRow(
                label: context.tr('usage.imageOutputTokens'),
                value: formatInt(log.imageOutputTokens!),
              ),
          ],
        ),
        const SizedBox(height: 20),
        SectionHeader(title: context.tr('usage.billingDetails')),
        _DetailCard(
          children: [
            if (log.inputCost != null)
              _InfoRow(
                label: context.tr('usage.inputCost'),
                value: formatCost(log.inputCost!, decimals: 6),
              ),
            if (log.outputCost != null)
              _InfoRow(
                label: context.tr('usage.outputCost'),
                value: formatCost(log.outputCost!, decimals: 6),
              ),
            if (log.cacheCreationCost != null)
              _InfoRow(
                label: context.tr('usage.cacheCreationCost'),
                value: formatCost(log.cacheCreationCost!, decimals: 6),
              ),
            if (log.cacheReadCost != null)
              _InfoRow(
                label: context.tr('usage.cacheReadCost'),
                value: formatCost(log.cacheReadCost!, decimals: 6),
              ),
            if (log.imageOutputCost != null && log.imageOutputCost! > 0)
              _InfoRow(
                label: context.tr('usage.imageOutputCost'),
                value: formatCost(log.imageOutputCost!, decimals: 6),
              ),
            if (log.rateMultiplier != null)
              _InfoRow(
                label: context.tr('usage.rateMultiplier'),
                value: log.rateMultiplier!.toStringAsFixed(4),
              ),
            if (log.billingType != null)
              _InfoRow(
                label: context.tr('usage.billingType'),
                value: '${log.billingType}',
              ),
            if (log.billingMode != null)
              _InfoRow(
                label: context.tr('usage.billingMode'),
                value: log.billingMode!,
              ),
            if (log.cacheTtlOverridden != null)
              _InfoRow(
                label: context.tr('usage.cacheTtlOverridden'),
                value: _formatBool(log.cacheTtlOverridden!),
              ),
          ],
        ),
        if (_hasImageDetails(log)) ...[
          const SizedBox(height: 20),
          SectionHeader(title: context.tr('usage.imageDetails')),
          _DetailCard(
            children: [
              if (log.imageCount != null)
                _InfoRow(
                  label: context.tr('usage.imageCount'),
                  value: formatInt(log.imageCount!),
                ),
              if (log.imageSize != null)
                _InfoRow(
                  label: context.tr('usage.imageSize'),
                  value: log.imageSize!,
                ),
              if (log.imageInputSize != null)
                _InfoRow(
                  label: context.tr('usage.imageInputSize'),
                  value: log.imageInputSize!,
                ),
              if (log.imageOutputSize != null)
                _InfoRow(
                  label: context.tr('usage.imageOutputSize'),
                  value: log.imageOutputSize!,
                ),
              if (log.imageSizeSource != null)
                _InfoRow(
                  label: context.tr('usage.imageSizeSource'),
                  value: log.imageSizeSource!,
                ),
              if (log.imageSizeBreakdown != null)
                _InfoRow(
                  label: context.tr('usage.imageSizeBreakdown'),
                  value: _formatJson(log.imageSizeBreakdown),
                  multiline: true,
                  monospace: true,
                ),
              if (log.mediaType != null)
                _InfoRow(
                  label: context.tr('usage.mediaType'),
                  value: log.mediaType!,
                ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        SectionHeader(title: context.tr('keys.overview')),
        _DetailCard(
          children: [
            _InfoRow(label: 'User ID', value: '${log.userId}'),
            _InfoRow(label: 'API Key ID', value: '${log.apiKeyId}'),
            if (log.apiKeyName != null)
              _InfoRow(
                label: context.tr('usageLogs.apiKey'),
                value: log.apiKeyName!,
              ),
            if (log.groupId != null)
              _InfoRow(label: 'Group ID', value: '${log.groupId}'),
            if (log.groupName != null)
              _InfoRow(label: context.tr('keys.group'), value: log.groupName!),
            if (log.subscriptionId != null)
              _InfoRow(
                label: context.tr('usage.subscriptionId'),
                value: '${log.subscriptionId}',
              ),
            if (log.accountId != null)
              _InfoRow(
                label: context.tr('usage.accountId'),
                value: '${log.accountId}',
              ),
          ],
        ),
        const SizedBox(height: 20),
        SectionHeader(title: context.tr('usage.apiResponse')),
        _DetailCard(
          children: [
            for (final entry in log.rawJson.entries)
              _InfoRow(
                label: entry.key,
                value: _formatValue(entry.value),
                multiline: entry.value is Map || entry.value is List,
                monospace: true,
              ),
          ],
        ),
      ],
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(children: children),
      ),
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
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.multiline = false,
    this.monospace = false,
  });

  final String label;
  final String value;
  final bool multiline;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final valueStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w500,
      fontFamily: monospace ? 'monospace' : null,
    );

    if (multiline) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            SelectableText(value, style: valueStyle),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SelectableText(
              value,
              textAlign: TextAlign.right,
              style: valueStyle,
            ),
          ),
        ],
      ),
    );
  }
}

bool _hasImageDetails(UsageLog log) =>
    (log.imageCount ?? 0) > 0 ||
    log.imageSize != null ||
    log.imageInputSize != null ||
    log.imageOutputSize != null ||
    log.imageSizeSource != null ||
    log.imageSizeBreakdown != null ||
    log.mediaType != null;

String _formatBool(bool value) => value ? 'true' : 'false';

String _formatValue(Object? value) {
  if (value == null) return 'null';
  if (value is Map || value is List) return _formatJson(value);
  return '$value';
}

String _formatJson(Object? value) {
  const encoder = JsonEncoder.withIndent('  ');
  return encoder.convert(value);
}
