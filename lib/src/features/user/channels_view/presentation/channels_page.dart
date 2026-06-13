import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../i18n/app_localizations.dart';
import '../../../../shared/format/formatters.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/responsive_center.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../data/channels_api.dart';
import '../providers/channels_providers.dart';

/// 可用渠道页:渠道 → 平台分区 → 分组(倍率/订阅)+ 支持模型(含定价)。
class ChannelsPage extends ConsumerWidget {
  const ChannelsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channelsAsync = ref.watch(availableChannelsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('features.availableChannels'))),
      body: ResponsiveCenter(
        child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(availableChannelsProvider);
          await ref.read(availableChannelsProvider.future);
        },
        child: AsyncValueView(
          value: channelsAsync,
          onRetry: () => ref.invalidate(availableChannelsProvider),
          builder: (context, channels) {
            if (channels.isEmpty) {
              return ListView(children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: EmptyState(
                    icon: Icons.hub_outlined,
                    message: context.tr('channels.empty'),
                  ),
                ),
              ]);
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              itemCount: channels.length,
              itemBuilder: (context, i) => _ChannelCard(channel: channels[i]),
            );
          },
        ),
      ),
      ),
    );
  }
}

class _ChannelCard extends StatelessWidget {
  const _ChannelCard({required this.channel});

  final AvailableChannel channel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(channel.name,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            if (channel.description.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(channel.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      )),
            ],
            for (final section in channel.platforms)
              _PlatformSection(section: section),
          ],
        ),
      ),
    );
  }
}

class _PlatformSection extends StatelessWidget {
  const _PlatformSection({required this.section});

  final ChannelPlatformSection section;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(section.platform.toUpperCase(),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  )),
          if (section.groups.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final g in section.groups) _GroupChip(group: g)],
            ),
          ],
          if (section.supportedModels.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final m in section.supportedModels) _ModelRow(model: m),
          ],
        ],
      ),
    );
  }
}

class _GroupChip extends StatelessWidget {
  const _GroupChip({required this.group});

  final AvailableChannelGroup group;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sub = group.isSubscription;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: sub
            ? AppColors.brandBlue.withValues(alpha: 0.12)
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (sub) ...[
            Icon(Icons.workspace_premium_outlined,
                size: 14, color: AppColors.brandBlue),
            const SizedBox(width: 4),
          ],
          Text(group.name,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Text('×${group.rateMultiplier.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  )),
        ],
      ),
    );
  }
}

class _ModelRow extends StatelessWidget {
  const _ModelRow({required this.model});

  final SupportedModel model;

  static const _perMillion = 1000000;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (!model.hasPricing) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(model.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium),
            ),
            StatusPill(
              label: context.tr('channels.noPricing'),
              tone: StatusTone.neutral,
              dense: true,
            ),
          ],
        ),
      );
    }
    return Theme(
      // 去掉 ExpansionTile 默认分隔线。
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(left: 8, bottom: 8),
        dense: true,
        visualDensity: VisualDensity.compact,
        title: Text(model.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium),
        subtitle: Text(
          _billingModeLabel(context),
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        children: _priceRows(context),
      ),
    );
  }

  String _billingModeLabel(BuildContext context) {
    switch (model.billingMode) {
      case 'per_request':
        return context.tr('channels.billingPerRequest');
      case 'image':
        return context.tr('channels.billingImage');
      default:
        return context.tr('channels.billingToken');
    }
  }

  List<Widget> _priceRows(BuildContext context) {
    if (model.billingMode == 'per_request') {
      return [
        _PriceLine(
            label: context.tr('channels.pricePerRequest'),
            value: formatScaledPrice(model.perRequestPrice, 1)),
      ];
    }
    if (model.billingMode == 'image') {
      return [
        _PriceLine(
            label: context.tr('channels.priceImage'),
            value: formatScaledPrice(model.imageOutputPrice, 1)),
      ];
    }
    // token 计费:每百万 token。
    return [
      _PriceLine(
          label: context.tr('channels.priceInput'),
          value: formatScaledPrice(model.inputPrice, _perMillion)),
      _PriceLine(
          label: context.tr('channels.priceOutput'),
          value: formatScaledPrice(model.outputPrice, _perMillion)),
      _PriceLine(
          label: context.tr('channels.priceCacheWrite'),
          value: formatScaledPrice(model.cacheWritePrice, _perMillion)),
      _PriceLine(
          label: context.tr('channels.priceCacheRead'),
          value: formatScaledPrice(model.cacheReadPrice, _perMillion)),
      if (model.imageOutputPrice != null && model.imageOutputPrice! > 0)
        _PriceLine(
            label: context.tr('channels.priceImage'),
            value: formatScaledPrice(model.imageOutputPrice, _perMillion)),
    ];
  }
}

/// 定价单行:标签 + 值(每百万 token)。
class _PriceLine extends StatelessWidget {
  const _PriceLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant)),
          ),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
