import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../i18n/app_localizations.dart';
import '../data/subscriptions_api.dart';
import '../providers/subscriptions_providers.dart';

/// 订阅管理页面。
class SubscriptionsPage extends ConsumerWidget {
  const SubscriptionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptionsAsync = ref.watch(subscriptionsListProvider);
    final progressAsync = ref.watch(subscriptionsProgressProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('subscriptions.title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(subscriptionsListProvider);
              ref.invalidate(subscriptionsProgressProvider);
            },
          ),
        ],
      ),
      body: subscriptionsAsync.when(
        data: (subscriptions) {
          if (subscriptions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.card_membership_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.tr('subscriptions.empty'),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: subscriptions.length,
            itemBuilder: (context, index) {
              final subscription = subscriptions[index];
              final progress = progressAsync.value?.firstWhere(
                (p) => p.subscriptionId == subscription.id,
                orElse: () => const SubscriptionProgress(subscriptionId: 0),
              );
              return _SubscriptionCard(
                subscription: subscription,
                progress: progress,
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline,
                  size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text(
                error is ApiException
                    ? error.serverMessage ?? context.tr('common.unknownError')
                    : context.tr('common.unknownError'),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () => ref.invalidate(subscriptionsListProvider),
                icon: const Icon(Icons.refresh),
                label: Text(context.tr('common.retry')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 订阅卡片。
class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({
    required this.subscription,
    this.progress,
  });

  final UserSubscription subscription;
  final SubscriptionProgress? progress;

  @override
  Widget build(BuildContext context) {
    final isActive = subscription.status == 'active';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    subscription.groupName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                _StatusChip(
                  status: subscription.status,
                  isActive: isActive,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (subscription.expiresAt != null) ...[
              _InfoRow(
                icon: Icons.event,
                label: context.tr('subscriptions.expires'),
                value: _formatDate(subscription.expiresAt!),
              ),
              if (subscription.daysRemaining != null)
                _InfoRow(
                  icon: Icons.timer,
                  label: context.tr('subscriptions.remaining'),
                  value: context.tr('subscriptions.daysCount',
                      params: {'days': subscription.daysRemaining.toString()}),
                ),
            ],
            if (progress != null && progress!.subscriptionId != 0) ...[
              const Divider(height: 24),
              Text(
                context.tr('subscriptions.usage'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 12),
              if (progress!.dailyLimit != null)
                _ProgressBar(
                  label: context.tr('subscriptions.daily'),
                  used: progress!.dailyUsed ?? 0,
                  limit: progress!.dailyLimit!,
                ),
              if (progress!.weeklyLimit != null) ...[
                const SizedBox(height: 8),
                _ProgressBar(
                  label: context.tr('subscriptions.weekly'),
                  used: progress!.weeklyUsed ?? 0,
                  limit: progress!.weeklyLimit!,
                ),
              ],
              if (progress!.monthlyLimit != null) ...[
                const SizedBox(height: 8),
                _ProgressBar(
                  label: context.tr('subscriptions.monthly'),
                  used: progress!.monthlyUsed ?? 0,
                  limit: progress!.monthlyLimit!,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

/// 状态标签。
class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.status,
    required this.isActive,
  });

  final String status;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        context.tr('subscriptions.status_$status'),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: isActive ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

/// 信息行。
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(width: 8),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// 进度条。
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.label,
    required this.used,
    required this.limit,
  });

  final String label;
  final double used;
  final double limit;

  @override
  Widget build(BuildContext context) {
    final progress = limit > 0 ? (used / limit).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            Text(
              '\$${used.toStringAsFixed(2)} / \$${limit.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}
