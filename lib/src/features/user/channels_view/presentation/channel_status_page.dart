import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../i18n/app_localizations.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../shared/widgets/availability_bar.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../../../../shared/widgets/uptime_timeline.dart';
import '../data/channels_api.dart';
import '../providers/channels_providers.dart';
import 'monitor_visuals.dart';

/// 渠道状态页:监控列表(状态/7 天可用率/延迟/时间轴),点击进多窗口详情。
class ChannelStatusPage extends ConsumerWidget {
  const ChannelStatusPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monitorsAsync = ref.watch(channelMonitorsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('features.channelStatus'))),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(channelMonitorsProvider);
          await ref.read(channelMonitorsProvider.future);
        },
        child: AsyncValueView(
          value: monitorsAsync,
          onRetry: () => ref.invalidate(channelMonitorsProvider),
          builder: (context, monitors) {
            if (monitors.isEmpty) {
              return ListView(children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: EmptyState(
                    icon: Icons.monitor_heart_outlined,
                    message: context.tr('channels.statusEmpty'),
                  ),
                ),
              ]);
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              itemCount: monitors.length,
              itemBuilder: (context, i) => _MonitorCard(monitor: monitors[i]),
            );
          },
        ),
      ),
    );
  }
}

class _MonitorCard extends StatelessWidget {
  const _MonitorCard({required this.monitor});

  final MonitorView monitor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ticks = monitor.timeline.map((p) => monitorTone(p.status)).toList();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => context.push('/channel-status/${monitor.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(monitor.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(
                          '${monitor.groupName} · ${monitor.primaryModel}',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusPill(
                    label: monitorStatusLabel(context, monitor.primaryStatus),
                    tone: monitorStatusTone(monitor.primaryStatus),
                    dense: true,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (ticks.isNotEmpty) ...[
                UptimeTimeline(ticks: ticks),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  Expanded(
                    child: AvailabilityBar(
                      percent: monitor.availability7d,
                      label: '7d',
                    ),
                  ),
                  if (monitor.primaryLatencyMs != null) ...[
                    const SizedBox(width: 12),
                    Text(
                      '${monitor.primaryLatencyMs} ms',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
