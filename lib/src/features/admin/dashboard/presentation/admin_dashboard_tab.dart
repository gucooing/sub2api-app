import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/session/session_controller.dart';
import '../../../../core/session/auth_models.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../i18n/app_localizations.dart';
import '../../../../shared/format/formatters.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_retry.dart';
import '../../../../shared/widgets/multi_series_trend_chart.dart';
import '../../../../shared/widgets/progress_meter.dart';
import '../../../../shared/widgets/responsive.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../../../../shared/widgets/token_trend_series.dart';
import '../../../user/features/data/user_features.dart';
import '../../../user/features/presentation/custom_page_launcher.dart';
import '../../shared/admin_modules.dart';
import '../data/admin_dashboard_api.dart';
import '../providers/admin_dashboard_providers.dart';

/// 管理端总览:平台 KPI 磁贴 + 账号健康度 + 用量趋势(多线图)。
class AdminDashboardTab extends ConsumerWidget {
  const AdminDashboardTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminDashboardStatsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(adminDashboardStatsProvider);
        ref.invalidate(adminDashboardTrendProvider);
        await ref.read(adminDashboardStatsProvider.future);
      },
      child: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          children: [
            const SizedBox(height: 120),
            ErrorRetryView(
              error: e,
              onRetry: () => ref.invalidate(adminDashboardStatsProvider),
            ),
          ],
        ),
        data: (stats) => _Content(stats: stats),
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.stats});

  final AdminDashboardStats stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendAsync = ref.watch(adminDashboardTrendProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        ResponsiveCenter(
          maxWidth: 1100,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Hero(stats: stats),
              const SizedBox(height: 16),
              SectionHeader(title: context.tr('admin.dashboard.kpis')),
              _MetricsCard(stats: stats),
              const SizedBox(height: 16),
              SectionHeader(title: context.tr('admin.dashboard.quickAccess')),
              const _QuickAccess(),
              const SizedBox(height: 16),
              SectionHeader(title: context.tr('admin.dashboard.accountHealth')),
              _AccountHealthCard(stats: stats),
              const SizedBox(height: 16),
              SectionHeader(title: context.tr('admin.dashboard.usageTrend')),
              _TrendCard(trendAsync: trendAsync),
            ],
          ),
        ),
      ],
    );
  }
}

/// 高密度核心指标:单卡内多列紧凑排布(值 + 小标签),信息密度优先。
class _MetricsCard extends StatelessWidget {
  const _MetricsCard({required this.stats});

  final AdminDashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final metrics = <(String, String, Color?)>[
      (
        context.tr('admin.dashboard.todayNewUsers'),
        '+${formatInt(stats.todayNewUsers)}',
        AppColors.brandGreen
      ),
      (context.tr('admin.dashboard.activeUsers'), formatInt(stats.activeUsers),
          null),
      (
        context.tr('admin.dashboard.apiKeys'),
        '${formatInt(stats.activeApiKeys)}/${formatInt(stats.totalApiKeys)}',
        null
      ),
      (
        context.tr('admin.dashboard.todayRequests'),
        formatCompact(stats.todayRequests),
        null
      ),
      (context.tr('admin.dashboard.rpm'), stats.rpm.toStringAsFixed(1), null),
      (
        context.tr('admin.dashboard.avgLatency'),
        '${stats.averageDurationMs.round()} ms',
        null
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        child: LayoutBuilder(
          builder: (context, c) {
            // 紧凑:每格约 110px,手机 3 列、宽屏更多。
            final cols = (c.maxWidth / 112).floor().clamp(2, 6);
            final cellW = c.maxWidth / cols;
            return Wrap(
              children: [
                for (final m in metrics)
                  SizedBox(
                    width: cellW,
                    child: _MetricCell(
                      label: m.$1,
                      value: m.$2,
                      accent: m.$3,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MetricCell extends StatelessWidget {
  const _MetricCell({required this.label, required this.value, this.accent});

  final String label;
  final String value;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: accent,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// 品牌渐变 hero:平台核心数(用户/账号/今日消耗/累计消耗)。
class _Hero extends StatelessWidget {
  const _Hero({required this.stats});

  final AdminDashboardStats stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('admin.dashboard.platformOverview'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _heroMetric(context, context.tr('admin.dashboard.totalUsers'),
                  formatInt(stats.totalUsers)),
              _heroMetric(context, context.tr('admin.dashboard.totalAccounts'),
                  formatInt(stats.totalAccounts)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _heroMetric(context, context.tr('admin.dashboard.todayCost'),
                  formatCost(stats.todayActualCost)),
              _heroMetric(context, context.tr('admin.dashboard.totalCost'),
                  formatCost(stats.totalActualCost)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _heroMetric(context, context.tr('admin.dashboard.todayTokens'),
                  formatCompact(stats.todayTokens)),
              _heroMetric(context, context.tr('admin.dashboard.totalTokens'),
                  formatCompact(stats.totalTokens)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroMetric(BuildContext context, String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                ),
          ),
        ],
      ),
    );
  }
}

/// 上游账号健康度:正常占比进度 + 各异常态药丸。
class _AccountHealthCard extends StatelessWidget {
  const _AccountHealthCard({required this.stats});

  final AdminDashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final total = stats.totalAccounts;
    final ratio = total > 0 ? stats.normalAccounts / total : 0.0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.tr('admin.dashboard.normalRatio'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  '${formatInt(stats.normalAccounts)}/${formatInt(total)}',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ProgressMeter(value: ratio, max: 1),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatusPill(
                  label:
                      '${context.tr('admin.dashboard.normal')} ${stats.normalAccounts}',
                  tone: StatusTone.positive,
                ),
                StatusPill(
                  label:
                      '${context.tr('admin.dashboard.error')} ${stats.errorAccounts}',
                  tone: stats.errorAccounts > 0
                      ? StatusTone.danger
                      : StatusTone.neutral,
                ),
                StatusPill(
                  label:
                      '${context.tr('admin.dashboard.rateLimited')} ${stats.ratelimitAccounts}',
                  tone: stats.ratelimitAccounts > 0
                      ? StatusTone.warning
                      : StatusTone.neutral,
                ),
                StatusPill(
                  label:
                      '${context.tr('admin.dashboard.overloaded')} ${stats.overloadAccounts}',
                  tone: stats.overloadAccounts > 0
                      ? StatusTone.warning
                      : StatusTone.neutral,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.trendAsync});

  final AsyncValue<List<DashboardTrendPoint>> trendAsync;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 12),
        child: SizedBox(
          height: 280,
          child: trendAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => EmptyState(
              icon: Icons.show_chart,
              message: context.tr('errors.network'),
            ),
            data: (points) => MultiSeriesTrendChart(
              labels: [for (final p in points) p.shortLabel],
              emptyHint: context.tr('common.empty'),
              series: tokenTrendSeries(
                context,
                input: [for (final p in points) p.inputTokens.toDouble()],
                output: [for (final p in points) p.outputTokens.toDouble()],
                cacheCreation: [
                  for (final p in points) p.cacheCreationTokens.toDouble()
                ],
                cacheRead: [
                  for (final p in points) p.cacheReadTokens.toDouble()
                ],
                cacheHitRate: [for (final p in points) p.cacheHitRate],
                amount: [for (final p in points) p.actualCost],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 快捷入口:管理端各模块 + 管理员自定义页面(对齐用户端总览的快捷入口)。
class _QuickAccess extends ConsumerWidget {
  const _QuickAccess();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(publicSettingsProvider).value;
    final customPages = settings == null
        ? const <CustomMenuItem>[]
        : visibleCustomPages(settings, isAdmin: true);

    final items = <_QaItem>[
      for (final m in visibleAdminModules(settings))
        _QaItem(m.icon, context.tr(m.labelKey), () => context.push(m.route)),
      for (final p in customPages)
        _QaItem(Icons.public_outlined, p.label,
            () => openCustomPage(context, ref, p)),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        child: LayoutBuilder(
          builder: (context, c) {
            final cols = (c.maxWidth / 96).floor().clamp(3, 6);
            final cellW = c.maxWidth / cols;
            return Wrap(
              children: [
                for (final it in items)
                  SizedBox(width: cellW, child: _QaCell(item: it)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _QaItem {
  const _QaItem(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _QaCell extends StatelessWidget {
  const _QaCell({required this.item});

  final _QaItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Column(
          children: [
            Icon(item.icon, color: scheme.primary),
            const SizedBox(height: 6),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
