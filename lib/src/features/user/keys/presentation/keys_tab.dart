import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../i18n/app_localizations.dart';
import '../../../../shared/format/formatters.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/progress_meter.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../data/keys_api.dart';
import '../providers/keys_providers.dart';
import 'key_edit_sheet.dart';

/// 密钥状态 → 统一色调。
StatusTone keyStatusTone(String status) => switch (status) {
      'active' => StatusTone.positive,
      'inactive' => StatusTone.neutral,
      'quota_exhausted' => StatusTone.danger,
      'expired' => StatusTone.danger,
      _ => StatusTone.neutral,
    };

String keyStatusLabel(BuildContext context, String status) => switch (status) {
      'active' => context.tr('keys.statusActive'),
      'inactive' => context.tr('keys.statusInactive'),
      'quota_exhausted' => context.tr('keys.statusQuotaExhausted'),
      'expired' => context.tr('keys.statusExpired'),
      _ => status,
    };

/// 「密钥」tab:API 密钥列表(状态/倍率/今日·累计消耗/配额进度),点击进详情。
class KeysTab extends ConsumerWidget {
  const KeysTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keys = ref.watch(keysListProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'keys-fab',
        onPressed: () => showKeyEditSheet(context, ref),
        icon: const Icon(Icons.add),
        label: Text(context.tr('keys.create')),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(keysListProvider);
          ref.invalidate(keysUsageProvider);
          try {
            await ref.read(keysListProvider.future);
          } on Exception {
            // 错误展示交给 AsyncValueView
          }
        },
        child: AsyncValueView(
          value: keys,
          onRetry: () => ref.invalidate(keysListProvider),
          builder: (context, list) {
            if (list.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  EmptyState(
                    icon: Icons.vpn_key_off_outlined,
                    message: context.tr('keys.emptyHint'),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _KeyCard(info: list[i]),
            );
          },
        ),
      ),
    );
  }
}

class _KeyCard extends ConsumerWidget {
  const _KeyCard({required this.info});

  final ApiKeyInfo info;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final usage = ref.watch(keysUsageProvider).value?[info.id];

    return Card(
      child: InkWell(
        onTap: () => context.push('/keys/${info.id}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      info.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (info.rateMultiplier != null &&
                      info.rateMultiplier != 1) ...[
                    _RateBadge(rate: info.rateMultiplier!),
                    const SizedBox(width: 6),
                  ],
                  StatusPill(
                    label: keyStatusLabel(context, info.status),
                    tone: keyStatusTone(info.status),
                  ),
                  _ActionsMenu(info: info),
                ],
              ),
              const SizedBox(height: 6),
              // 密钥脱敏 + 复制
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: info.key));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.tr('common.copied'))),
                    );
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          info.maskedKey,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontFamily: 'monospace'),
                        ),
                      ),
                      Icon(Icons.copy, size: 16, color: scheme.primary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // 今日 / 累计消耗
              Row(
                children: [
                  Expanded(
                    child: _CostStat(
                      label: context.tr('keys.todayCost'),
                      value: usage != null
                          ? formatCost(usage.todayActualCost)
                          : '—',
                    ),
                  ),
                  Expanded(
                    child: _CostStat(
                      label: context.tr('keys.totalCost'),
                      value: usage != null
                          ? formatCost(usage.totalActualCost)
                          : '—',
                    ),
                  ),
                ],
              ),
              if (info.quota > 0) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(context.tr('keys.quota'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant)),
                    const Spacer(),
                    Text(
                      '${formatCost(info.quotaUsed)} / ${formatCost(info.quota)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ProgressMeter(value: info.quotaUsed, max: info.quota),
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  if (info.groupName != null)
                    _Meta(icon: Icons.folder_outlined, text: info.groupName!),
                  if (info.expiresAt != null)
                    _Meta(
                      icon: Icons.schedule_outlined,
                      text:
                          '${context.tr('keys.expires')} ${formatDate(info.expiresAt!)}',
                    ),
                  _Meta(
                    icon: Icons.chevron_right,
                    text: context.tr('keys.detail'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RateBadge extends StatelessWidget {
  const _RateBadge({required this.rate});

  final double rate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        '×${rate.toStringAsFixed(rate.truncateToDouble() == rate ? 0 : 2)}',
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: scheme.onTertiaryContainer, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _CostStat extends StatelessWidget {
  const _CostStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _ActionsMenu extends ConsumerWidget {
  const _ActionsMenu({required this.info});

  final ApiKeyInfo info;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MenuAnchor(
      builder: (context, controller, _) => IconButton(
        icon: const Icon(Icons.more_vert),
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Icons.edit_outlined),
          onPressed: () => showKeyEditSheet(context, ref, existing: info),
          child: Text(context.tr('common.edit')),
        ),
        MenuItemButton(
          leadingIcon: Icon(
            info.isActive
                ? Icons.pause_circle_outline
                : Icons.play_circle_outline,
          ),
          onPressed: () => _toggle(context, ref),
          child: Text(
            info.isActive
                ? context.tr('keys.disable')
                : context.tr('keys.enable'),
          ),
        ),
        MenuItemButton(
          leadingIcon: Icon(
            Icons.delete_outline,
            color: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => _confirmDelete(context, ref),
          child: Text(
            context.tr('common.delete'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ],
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(keysApiProvider).update(
            info.id,
            status: info.isActive ? 'inactive' : 'active',
          );
      ref.invalidate(keysListProvider);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.localizedMessage(context))),
        );
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('common.delete')),
        content:
            Text(context.tr('keys.deleteConfirm', params: {'name': info.name})),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('common.cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.tr('common.delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(keysApiProvider).remove(info.id);
      ref.invalidate(keysListProvider);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.localizedMessage(context))),
        );
      }
    }
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}
