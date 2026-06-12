import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/session/session_controller.dart';
import '../../../../i18n/app_localizations.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../providers/dashboard_providers.dart';

/// 「总览」tab:余额 + 今日/累计用量统计卡片。
class DashboardTab extends ConsumerWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dashboardStatsProvider);
    final user = ref.watch(sessionControllerProvider).user;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('nav.dashboard'))),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardStatsProvider);
          await ref.read(sessionControllerProvider.notifier).refreshUser();
          try {
            await ref.read(dashboardStatsProvider.future);
          } on Exception {
            // 错误展示交给 AsyncValueView
          }
        },
        child: AsyncValueView(
          value: stats,
          onRetry: () => ref.invalidate(dashboardStatsProvider),
          builder: (context, data) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 余额卡片
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('dashboard.balance'),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$${(user?.balance ?? 0).toStringAsFixed(2)}',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                context.tr('dashboard.today'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              _StatGrid(items: [
                _StatItem(
                  label: context.tr('dashboard.requests'),
                  value: '${data.todayRequests}',
                  icon: Icons.swap_vert,
                ),
                _StatItem(
                  label: context.tr('dashboard.cost'),
                  value: '\$${data.todayActualCost.toStringAsFixed(4)}',
                  icon: Icons.payments_outlined,
                ),
                _StatItem(
                  label: context.tr('dashboard.tokens'),
                  value: _formatTokens(data.todayTokens),
                  icon: Icons.token_outlined,
                ),
                _StatItem(
                  label: 'RPM / TPM',
                  value:
                      '${data.rpm.toStringAsFixed(1)} / ${_formatTokens(data.tpm.round())}',
                  icon: Icons.speed_outlined,
                ),
              ]),
              const SizedBox(height: 16),
              Text(
                context.tr('dashboard.total'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              _StatGrid(items: [
                _StatItem(
                  label: context.tr('dashboard.requests'),
                  value: '${data.totalRequests}',
                  icon: Icons.swap_vert,
                ),
                _StatItem(
                  label: context.tr('dashboard.cost'),
                  value: '\$${data.totalActualCost.toStringAsFixed(2)}',
                  icon: Icons.payments_outlined,
                ),
                _StatItem(
                  label: context.tr('dashboard.tokens'),
                  value: _formatTokens(data.totalTokens),
                  icon: Icons.token_outlined,
                ),
                _StatItem(
                  label: context.tr('dashboard.keys'),
                  value: '${data.activeApiKeys} / ${data.totalApiKeys}',
                  icon: Icons.vpn_key_outlined,
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatTokens(int tokens) {
    if (tokens >= 1000000000) {
      return '${(tokens / 1000000000).toStringAsFixed(2)}B';
    }
    if (tokens >= 1000000) return '${(tokens / 1000000).toStringAsFixed(2)}M';
    if (tokens >= 1000) return '${(tokens / 1000).toStringAsFixed(1)}K';
    return '$tokens';
  }
}

class _StatItem {
  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.items});

  final List<_StatItem> items;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.9,
      children: [
        for (final item in items)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Icon(
                        item.icon,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.label,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      item.value,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
