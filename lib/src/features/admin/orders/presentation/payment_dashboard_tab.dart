import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../i18n/app_localizations.dart';
import '../../../../shared/format/formatters.dart';
import '../../../../shared/widgets/error_retry.dart';
import '../../../../shared/widgets/metric_trend_chart.dart';
import '../../../../shared/widgets/responsive.dart';
import '../data/admin_payment_api.dart';
import '../providers/admin_payment_providers.dart';
import 'orders_tab.dart' show paymentMethodLabel;

/// 支付看板 Tab:天数切换 + 统计卡 + 每日收入 + 支付方式分布 + Top 用户。
class PaymentDashboardTab extends ConsumerStatefulWidget {
  const PaymentDashboardTab({super.key});

  @override
  ConsumerState<PaymentDashboardTab> createState() =>
      _PaymentDashboardTabState();
}

class _PaymentDashboardTabState extends ConsumerState<PaymentDashboardTab>
    with AutomaticKeepAliveClientMixin {
  int _days = 30;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final async = ref.watch(adminPaymentDashboardProvider(_days));
    return Column(
      children: [
        ResponsiveCenter(
          maxWidth: 1100,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<int>(
                    segments: [
                      for (final d in const [7, 30, 90])
                        ButtonSegment(
                          value: d,
                          label: Text('$d${context.tr('adminOrders.daySuffix')}'),
                        ),
                    ],
                    selected: {_days},
                    onSelectionChanged: (s) => setState(() => _days = s.first),
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () =>
                      ref.invalidate(adminPaymentDashboardProvider(_days)),
                  icon: const Icon(Icons.refresh),
                  tooltip: context.tr('common.refresh'),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorRetryView(
                error: e,
                onRetry: () =>
                    ref.invalidate(adminPaymentDashboardProvider(_days))),
            data: (stats) => RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(adminPaymentDashboardProvider(_days)),
              child: ResponsiveCenter(
                maxWidth: 1100,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(10, 4, 10, 24),
                  children: [
                    _statsCard(context, stats),
                    const SizedBox(height: 10),
                    _revenueChartCard(context, stats),
                    const SizedBox(height: 10),
                    _distributionCard(context, stats),
                    const SizedBox(height: 10),
                    _topUsersCard(context, stats),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _statsCard(BuildContext context, PaymentDashboardStats s) {
    final cells = [
      (
        context.tr('adminOrders.todayRevenue'),
        '\$${s.todayAmount.toStringAsFixed(2)}',
        '${s.todayCount} ${context.tr('adminOrders.orders')}'
      ),
      (
        context.tr('adminOrders.totalRevenue'),
        '\$${s.totalAmount.toStringAsFixed(2)}',
        '${s.totalCount} ${context.tr('adminOrders.orders')}'
      ),
      (
        context.tr('adminOrders.todayOrders'),
        '${s.todayCount}',
        ''
      ),
      (
        context.tr('adminOrders.avgAmount'),
        '\$${s.avgAmount.toStringAsFixed(2)}',
        ''
      ),
    ];
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth >= 520 ? 4 : 2;
          final w = (c.maxWidth - (cols - 1) * 12) / cols;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final cell in cells)
                SizedBox(width: w, child: _metricCell(context, cell)),
            ],
          );
        }),
      ),
    );
  }

  Widget _metricCell(
      BuildContext context, (String, String, String) cell) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(cell.$1,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(cell.$2,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        if (cell.$3.isNotEmpty)
          Text(cell.$3,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant)),
      ],
    );
  }

  Widget _revenueChartCard(BuildContext context, PaymentDashboardStats s) {
    final points = [
      for (final p in s.dailySeries)
        TrendChartPoint(label: _shortDate(p.date), value: p.amount.toDouble()),
    ];
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('adminOrders.dailyRevenue'),
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SizedBox(
              height: 220,
              child: MetricTrendChart(
                points: points,
                valueLabel: (v) => '¥${formatCompact(v)}',
                emptyHint: context.tr('adminOrders.noData'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _distributionCard(BuildContext context, PaymentDashboardStats s) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('adminOrders.paymentDistribution'),
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (s.paymentMethods.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                    child: Text(context.tr('adminOrders.noData'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant))),
              )
            else
              for (final m in s.paymentMethods)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                            color: _methodColor(m.type, scheme),
                            shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(paymentMethodLabel(context, m.type),
                              style: Theme.of(context).textTheme.bodyMedium)),
                      Text('¥${m.amount.toStringAsFixed(2)}',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 6),
                      Text('(${m.count})',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _topUsersCard(BuildContext context, PaymentDashboardStats s) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('adminOrders.topUsers'),
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (s.topUsers.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                    child: Text(context.tr('adminOrders.noData'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant))),
              )
            else
              for (var i = 0; i < s.topUsers.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: _rankColor(i, scheme),
                            shape: BoxShape.circle),
                        child: Text('${i + 1}',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(s.topUsers[i].email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium)),
                      Text('¥${s.topUsers[i].amount.toStringAsFixed(2)}',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  static String _shortDate(String date) {
    final d = DateTime.tryParse(date);
    return d == null
        ? (date.length >= 5 ? date.substring(date.length - 5) : date)
        : formatMonthDay(d);
  }

  static Color _methodColor(String type, ColorScheme scheme) => switch (type) {
        'alipay' || 'alipay_direct' => Colors.blue,
        'wxpay' || 'wxpay_direct' => Colors.green,
        'stripe' => Colors.deepPurple,
        'airwallex' => Colors.teal,
        _ => scheme.outline,
      };

  static Color _rankColor(int idx, ColorScheme scheme) => switch (idx) {
        0 => Colors.amber,
        1 => Colors.blueGrey,
        2 => Colors.brown,
        _ => scheme.surfaceContainerHighest,
      };
}
