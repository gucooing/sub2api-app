import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../i18n/app_localizations.dart';
import '../../../../shared/format/formatters.dart';
import '../../../../shared/widgets/error_retry.dart';
import '../../../../shared/widgets/responsive.dart';
import '../providers/admin_ops_providers.dart';

const _timeRanges = ['5m', '30m', '1h', '6h', '24h'];

/// 运维总览 Tab:时间范围 + 流量/质量/延迟 KPI。
class OpsOverviewTab extends ConsumerStatefulWidget {
  const OpsOverviewTab({super.key});

  @override
  ConsumerState<OpsOverviewTab> createState() => _OpsOverviewTabState();
}

class _OpsOverviewTabState extends ConsumerState<OpsOverviewTab>
    with AutomaticKeepAliveClientMixin {
  String _range = '1h';

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final async = ref.watch(opsOverviewProvider(_range));
    return Column(
      children: [
        ResponsiveCenter(
          maxWidth: 1100,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
            child: Row(children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final r in _timeRanges)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(r),
                            selected: _range == r,
                            onSelected: (_) => setState(() => _range = r),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: () => ref.invalidate(opsOverviewProvider(_range)),
                icon: const Icon(Icons.refresh),
                tooltip: context.tr('common.refresh'),
              ),
            ]),
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorRetryView(
                error: e,
                onRetry: () => ref.invalidate(opsOverviewProvider(_range))),
            data: (o) => RefreshIndicator(
              onRefresh: () async => ref.invalidate(opsOverviewProvider(_range)),
              child: ResponsiveCenter(
                maxWidth: 1100,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(10, 4, 10, 24),
                  children: [
                    _section(context, 'adminOps.traffic', [
                      ('adminOps.qps',
                          '${o.qpsCurrent.toStringAsFixed(1)} / ${o.qpsPeak.toStringAsFixed(1)}'),
                      ('adminOps.tps',
                          '${o.tpsCurrent.toStringAsFixed(1)} / ${o.tpsPeak.toStringAsFixed(1)}'),
                      ('adminOps.requests', formatInt(o.requestCountTotal)),
                      ('adminOps.success', formatInt(o.successCount)),
                      ('adminOps.errors', formatInt(o.errorCountTotal)),
                      ('adminOps.tokens', formatCompact(o.tokenConsumed)),
                    ]),
                    const SizedBox(height: 10),
                    _section(context, 'adminOps.quality', [
                      if (o.healthScore != null)
                        ('adminOps.health',
                            o.healthScore!.toStringAsFixed(0)),
                      ('adminOps.sla', '${(o.sla * 100).toStringAsFixed(2)}%'),
                      ('adminOps.errorRate',
                          '${(o.errorRate * 100).toStringAsFixed(2)}%'),
                      ('adminOps.upstreamErrorRate',
                          '${(o.upstreamErrorRate * 100).toStringAsFixed(2)}%'),
                      ('adminOps.upstream429', formatInt(o.upstream429Count)),
                      ('adminOps.upstream529', formatInt(o.upstream529Count)),
                    ]),
                    const SizedBox(height: 10),
                    _section(context, 'adminOps.latency', [
                      ('adminOps.durationP50', _ms(o.duration.p50)),
                      ('adminOps.durationP95', _ms(o.duration.p95)),
                      ('adminOps.durationP99', _ms(o.duration.p99)),
                      ('adminOps.ttftP95', _ms(o.ttft.p95)),
                      ('adminOps.ttftP99', _ms(o.ttft.p99)),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static String _ms(num? v) => v == null ? '-' : '${v.toStringAsFixed(0)} ms';

  Widget _section(
      BuildContext context, String titleKey, List<(String, String)> cells) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr(titleKey),
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            LayoutBuilder(builder: (context, c) {
              final cols = c.maxWidth >= 520 ? 3 : 2;
              final w = (c.maxWidth - (cols - 1) * 12) / cols;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final cell in cells)
                    SizedBox(
                      width: w,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(context.tr(cell.$1),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          Text(cell.$2,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}
