import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../i18n/app_localizations.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../shared/widgets/availability_bar.dart';
import '../../../../shared/widgets/responsive_center.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../data/channels_api.dart';
import '../providers/channels_providers.dart';
import 'monitor_visuals.dart';

/// 渠道监控详情:每个模型的多窗口可用率(7/15/30 天)+ 延迟。
class MonitorDetailPage extends ConsumerWidget {
  const MonitorDetailPage({super.key, required this.monitorId});

  final int monitorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(monitorStatusProvider(monitorId));

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('features.channelStatus'))),
      body: ResponsiveCenter(
        child: AsyncValueView(
        value: detailAsync,
        onRetry: () => ref.invalidate(monitorStatusProvider(monitorId)),
        builder: (context, detail) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Text(detail.name,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              '${detail.provider} · ${detail.groupName}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            for (final m in detail.models) _ModelCard(model: m),
          ],
        ),
      ),
      ),
    );
  }
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({required this.model});

  final MonitorModelDetail model;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(model.model,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                StatusPill(
                  label: monitorStatusLabel(context, model.latestStatus),
                  tone: monitorStatusTone(model.latestStatus),
                  dense: true,
                ),
              ],
            ),
            const SizedBox(height: 12),
            AvailabilityBar(percent: model.availability7d, label: '7d'),
            const SizedBox(height: 6),
            AvailabilityBar(percent: model.availability15d, label: '15d'),
            const SizedBox(height: 6),
            AvailabilityBar(percent: model.availability30d, label: '30d'),
            if (model.avgLatency7dMs != null) ...[
              const SizedBox(height: 10),
              Text(
                context.tr('channels.avgLatency',
                    params: {'ms': model.avgLatency7dMs.toString()}),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
