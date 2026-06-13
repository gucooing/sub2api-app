import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../i18n/app_localizations.dart';
import '../../../../shared/format/formatters.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../shared/widgets/availability_bar.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/responsive.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../../../../shared/widgets/uptime_timeline.dart';
import '../data/channels_api.dart';
import '../providers/channels_providers.dart';
import 'monitor_visuals.dart';

/// 时间轴展示的固定点数(对齐 web:最近 60 次)。
const int kMonitorHistoryPoints = 60;

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
      body: ResponsiveCenter(
        child: RefreshIndicator(
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
              MonitorTimelineBars(timeline: monitor.timeline),
              const SizedBox(height: 10),
              AvailabilityBar(percent: monitor.availability7d, label: '7d'),
            ],
          ),
        ),
      ),
    );
  }
}

/// 对齐 web 的监控时间轴:60 根高度+颜色双重编码的柱(底对齐,最新在右,
/// 左侧空位补齐),点按显示「时间·状态·延迟」。
class MonitorTimelineBars extends StatelessWidget {
  const MonitorTimelineBars({
    super.key,
    required this.timeline,
    this.trackHeight = 32,
    this.points = kMonitorHistoryPoints,
  });

  final List<MonitorTimelinePoint> timeline;
  final double trackHeight;
  final int points;

  /// 各状态柱高百分比(对齐 web)。
  double _heightPct(MonitorStatus s) => switch (s) {
        MonitorStatus.operational => 1.0,
        MonitorStatus.degraded => 0.65,
        MonitorStatus.failed => 0.35,
        MonitorStatus.unknown => 0.15,
      };

  @override
  Widget build(BuildContext context) {
    // 后端最新在前 → 取最近 points 个,反转为左旧右新。
    final real = timeline.take(points).toList().reversed.toList();
    final pad = points - real.length;
    final emptyColor = Theme.of(context).colorScheme.surfaceContainerHighest;

    return SizedBox(
      height: trackHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < pad; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0.5),
                child: FractionallySizedBox(
                  heightFactor: 0.15,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: emptyColor,
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                ),
              ),
            ),
          for (final p in real)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0.5),
                child: Tooltip(
                  message: _tooltip(context, p),
                  triggerMode: TooltipTriggerMode.tap,
                  child: FractionallySizedBox(
                    heightFactor: _heightPct(p.status),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: monitorToneColor(monitorTone(p.status)),
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _tooltip(BuildContext context, MonitorTimelinePoint p) {
    final time = p.checkedAt != null ? formatDateTime(p.checkedAt!) : '';
    final label = monitorStatusLabel(context, p.status);
    final latency = p.latencyMs != null ? '${p.latencyMs}ms' : '-';
    return [if (time.isNotEmpty) time, label, latency].join(' · ');
  }
}
