import 'dart:async';

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

/// 时间轴展示的固定点数(对齐 web:最近 60 次)。
const int kMonitorHistoryPoints = 60;

/// 把监控时间轴(后端最新在前)整理成左旧右新、补足到 60 个的色调序列。
List<MonitorTone> buildTimelineTicks(List<MonitorTimelinePoint> timeline) {
  final recent =
      timeline.take(kMonitorHistoryPoints).toList().reversed.toList();
  final pad = kMonitorHistoryPoints - recent.length;
  return [
    for (var i = 0; i < pad; i++) MonitorTone.unknown,
    for (final p in recent) monitorTone(p.status),
  ];
}

/// 渠道状态页:监控列表(状态/可用率/延迟/最近 60 次时间轴),自动刷新,点击进详情。
class ChannelStatusPage extends ConsumerStatefulWidget {
  const ChannelStatusPage({super.key});

  @override
  ConsumerState<ChannelStatusPage> createState() => _ChannelStatusPageState();
}

class _ChannelStatusPageState extends ConsumerState<ChannelStatusPage> {
  Timer? _timer;
  bool _autoRefresh = true;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    if (_autoRefresh) {
      _timer = Timer.periodic(const Duration(seconds: 60), (_) {
        if (mounted) ref.invalidate(channelMonitorsProvider);
      });
    }
  }

  void _toggleAutoRefresh() {
    setState(() => _autoRefresh = !_autoRefresh);
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final monitorsAsync = ref.watch(channelMonitorsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('features.channelStatus')),
        actions: [
          IconButton(
            tooltip: context.tr(
                _autoRefresh ? 'channels.autoRefreshOn' : 'channels.autoRefreshOff'),
            icon: Icon(_autoRefresh ? Icons.sync : Icons.sync_disabled),
            onPressed: _toggleAutoRefresh,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(channelMonitorsProvider),
          ),
        ],
      ),
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
    final ticks = buildTimelineTicks(monitor.timeline);
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
              Row(
                children: [
                  Text(
                    context.tr('channels.recentHistory',
                        params: {'n': kMonitorHistoryPoints.toString()}),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                  if (monitor.primaryLatencyMs != null) ...[
                    const Spacer(),
                    Text(
                      '${monitor.primaryLatencyMs} ms',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              UptimeTimeline(ticks: ticks, spacing: 1),
              const SizedBox(height: 10),
              AvailabilityBar(percent: monitor.availability7d, label: '7d'),
            ],
          ),
        ),
      ),
    );
  }
}
