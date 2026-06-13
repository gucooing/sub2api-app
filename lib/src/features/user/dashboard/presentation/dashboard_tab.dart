import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/session/session_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../i18n/app_localizations.dart';
import '../../../../shared/format/formatters.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../shared/widgets/brand_header.dart';
import '../../../../shared/widgets/kpi_tile.dart';
import '../../../../shared/widgets/multi_series_trend_chart.dart';
import '../../../../shared/widgets/pill_segmented.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/token_composition.dart';
import '../../../../shared/widgets/token_trend_series.dart';
import '../../features/data/user_features.dart';
import '../data/dashboard_api.dart';
import '../providers/dashboard_providers.dart';

enum _Period { today, total }

/// 「总览」tab:品牌 hero(余额 + RPM/TPM/活跃密钥)+ KPI 磁贴(迷你折线+涨跌)
/// + 消耗/Tokens 双指标趋势图 + 平台分布 + 快捷入口。
class DashboardTab extends ConsumerStatefulWidget {
  const DashboardTab({super.key});

  @override
  ConsumerState<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends ConsumerState<DashboardTab> {
  _Period _period = _Period.today;

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(dashboardStatsProvider);
    final trend = ref.watch(dashboardTrendProvider);
    final hourlyTrend = ref.watch(dashboardHourlyTrendProvider);
    final user = ref.watch(sessionControllerProvider).user;
    final trendList = trend.value ?? const <DashboardTrendPoint>[];

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardStatsProvider);
          ref.invalidate(dashboardTrendProvider);
          ref.invalidate(dashboardHourlyTrendProvider);
          await ref.read(sessionControllerProvider.notifier).refreshUser();
          try {
            await ref.read(dashboardStatsProvider.future);
            await ref.read(dashboardTrendProvider.future);
            await ref.read(dashboardHourlyTrendProvider.future);
          } on Exception {
            // 错误展示交给 AsyncValueView
          }
        },
        child: AsyncValueView(
          value: stats,
          onRetry: () => ref.invalidate(dashboardStatsProvider),
          builder: (context, data) => ListView(
            padding: EdgeInsets.zero,
            children: [
              _Hero(balance: user?.balance ?? 0, stats: data),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: PillSegmented<_Period>(
                        selected: _period,
                        onChanged: (p) => setState(() => _period = p),
                        options: [
                          (_Period.today, context.tr('dashboard.today')),
                          (_Period.total, context.tr('dashboard.total')),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _KpiGrid(
                      stats: data,
                      trend: trendList,
                      period: _period,
                    ),
                    const SizedBox(height: 20),
                    SectionHeader(title: context.tr('tokens.composition')),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: _TokenCompositionView(
                          stats: data,
                          isToday: _period == _Period.today,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SectionHeader(title: context.tr('dashboard.trend')),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 16, 16, 12),
                        child: SizedBox(
                          height: 280,
                          child: AsyncValueView(
                            value: hourlyTrend,
                            onRetry: () =>
                                ref.invalidate(dashboardHourlyTrendProvider),
                            builder: (context, points) => MultiSeriesTrendChart(
                              labels: [for (final p in points) p.shortLabel],
                              series: _trendSeries(context, points),
                              emptyHint: context.tr('common.empty'),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (data.byPlatform.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      SectionHeader(title: context.tr('dashboard.byPlatform')),
                      for (final p in data.byPlatform)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _PlatformCard(stats: p, period: _period),
                        ),
                    ],
                    const SizedBox(height: 20),
                    SectionHeader(title: context.tr('dashboard.quickAccess')),
                    const _QuickAccessRow(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 多线趋势图的系列:复用共享构造器,从总览趋势点取各字段。
List<TrendSeries> _trendSeries(
  BuildContext context,
  List<DashboardTrendPoint> points,
) {
  return tokenTrendSeries(
    context,
    input: [for (final p in points) p.inputTokens.toDouble()],
    output: [for (final p in points) p.outputTokens.toDouble()],
    cacheCreation: [for (final p in points) p.cacheCreationTokens.toDouble()],
    cacheRead: [for (final p in points) p.cacheReadTokens.toDouble()],
    cacheHitRate: [for (final p in points) p.cacheHitRate],
    amount: [for (final p in points) p.actualCost],
  );
}

class _Hero extends StatelessWidget {
  const _Hero({required this.balance, required this.stats});

  final double balance;
  final UserDashboardStats stats;

  @override
  Widget build(BuildContext context) {
    return BrandHeader(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('dashboard.balance'),
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            formatCost(balance),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _HeroStat(label: 'RPM', value: stats.rpm.toStringAsFixed(1)),
              _HeroStat(label: 'TPM', value: formatCompact(stats.tpm.round())),
              _HeroStat(
                label: context.tr('dashboard.activeKeys'),
                value: '${stats.activeApiKeys}/${stats.totalApiKeys}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({
    required this.stats,
    required this.trend,
    required this.period,
  });

  final UserDashboardStats stats;
  final List<DashboardTrendPoint> trend;
  final _Period period;

  /// 末位较前一位的涨跌(仅今日视角下展示)。
  double? _delta(double Function(DashboardTrendPoint) sel) {
    if (period != _Period.today || trend.length < 2) return null;
    return deltaPercent(sel(trend.last), sel(trend[trend.length - 2]));
  }

  List<double> _spark(double Function(DashboardTrendPoint) sel) =>
      [for (final p in trend) sel(p)];

  @override
  Widget build(BuildContext context) {
    final isToday = period == _Period.today;
    return LayoutBuilder(
      builder: (context, constraints) {
        // 按可用宽度自适应列数,并用固定磁贴高度,避免桌面宽屏下方块被拉得过大。
        final columns = (constraints.maxWidth / 200).floor().clamp(2, 4);
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          mainAxisExtent: 118,
          children: [
            KpiTile(
              label: context.tr('dashboard.cost'),
              icon: Icons.payments_outlined,
              value:
                  formatCost(isToday ? stats.todayActualCost : stats.totalActualCost),
              deltaPercent: _delta((p) => p.actualCost),
              spark: _spark((p) => p.actualCost),
            ),
        KpiTile(
          label: context.tr('dashboard.requests'),
          icon: Icons.swap_vert,
          value: formatInt(isToday ? stats.todayRequests : stats.totalRequests),
          deltaPercent: _delta((p) => p.requests.toDouble()),
          spark: _spark((p) => p.requests.toDouble()),
          accent: AppColors.brandBlue,
        ),
        KpiTile(
          label: context.tr('dashboard.tokens'),
          icon: Icons.token_outlined,
          value: formatCompact(isToday ? stats.todayTokens : stats.totalTokens),
          deltaPercent: _delta((p) => p.totalTokens.toDouble()),
          spark: _spark((p) => p.totalTokens.toDouble()),
          accent: AppColors.brandGreen,
        ),
        KpiTile(
          label: context.tr('dashboard.avgDuration'),
          icon: Icons.timer_outlined,
          value: '${stats.averageDurationMs.toStringAsFixed(0)}ms',
        ),
          ],
        );
      },
    );
  }
}

class _PlatformCard extends StatelessWidget {
  const _PlatformCard({required this.stats, required this.period});

  final PlatformStats stats;
  final _Period period;

  @override
  Widget build(BuildContext context) {
    final isToday = period == _Period.today;
    final requests = isToday ? stats.todayRequests : stats.totalRequests;
    final cost = isToday ? stats.todayActualCost : stats.totalActualCost;
    final tokens = isToday ? stats.todayTokens : stats.totalTokens;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_outlined,
                    size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  stats.platform,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                    child: _MiniStat(
                        label: context.tr('dashboard.requests'),
                        value: formatInt(requests))),
                Expanded(
                    child: _MiniStat(
                        label: context.tr('dashboard.cost'),
                        value: formatCost(cost))),
                Expanded(
                    child: _MiniStat(
                        label: context.tr('dashboard.tokens'),
                        value: formatCompact(tokens))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )),
        const SizedBox(height: 2),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _TokenCompositionView extends StatelessWidget {
  const _TokenCompositionView({required this.stats, required this.isToday});

  final UserDashboardStats stats;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    return TokenComposition(
      segments: [
        TokenSegment(
          label: context.tr('tokens.input'),
          value: isToday ? stats.todayInputTokens : stats.totalInputTokens,
          color: AppColors.brandBlue,
        ),
        TokenSegment(
          label: context.tr('tokens.output'),
          value: isToday ? stats.todayOutputTokens : stats.totalOutputTokens,
          color: AppColors.brandGreen,
        ),
        TokenSegment(
          label: context.tr('tokens.cacheCreation'),
          value: isToday
              ? stats.todayCacheCreationTokens
              : stats.totalCacheCreationTokens,
          color: const Color(0xFFF59E0B),
        ),
        TokenSegment(
          label: context.tr('tokens.cacheRead'),
          value: isToday
              ? stats.todayCacheReadTokens
              : stats.totalCacheReadTokens,
          color: const Color(0xFF8B5CF6),
        ),
      ],
    );
  }
}

class _QuickAccessRow extends ConsumerWidget {
  const _QuickAccessRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(publicSettingsProvider).value;
    final features = settings == null
        ? const <UserFeature>[]
        : enabledUserFeatures(settings);

    // 已开启的可选功能优先,再用常用入口补足到 4 个。
    final tiles = <_QuickTileData>[
      for (final f in features)
        _QuickTileData(
          icon: f.icon,
          label: context.tr(f.labelKey),
          onTap: () => context.push(f.route),
        ),
    ];
    final defaults = <_QuickTileData>[
      _QuickTileData(
        icon: Icons.list_alt_outlined,
        label: context.tr('usageLogs.title'),
        onTap: () => context.push('/usage-logs'),
      ),
      _QuickTileData(
        icon: Icons.card_membership_outlined,
        label: context.tr('nav.subscriptions'),
        onTap: () => context.push('/subscriptions'),
      ),
      _QuickTileData(
        icon: Icons.notifications_outlined,
        label: context.tr('announcements.title'),
        onTap: () => context.push('/announcements'),
      ),
    ];
    for (final d in defaults) {
      if (tiles.length >= 4) break;
      tiles.add(d);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 10.0;
        final perRow = tiles.length <= 3 ? tiles.length : 4;
        final width =
            (constraints.maxWidth - spacing * (perRow - 1)) / perRow;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final t in tiles)
              SizedBox(
                width: width,
                child: _QuickTile(
                  icon: t.icon,
                  label: t.label,
                  onTap: t.onTap,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _QuickTileData {
  const _QuickTileData({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: scheme.primary),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
