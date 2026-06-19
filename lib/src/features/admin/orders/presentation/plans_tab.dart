import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../i18n/app_localizations.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_retry.dart';
import '../../../../shared/widgets/responsive.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../../groups/data/admin_groups_api.dart';
import '../../groups/providers/admin_groups_providers.dart';
import '../data/admin_payment_api.dart';
import '../providers/admin_payment_providers.dart';

/// 订阅计划 Tab:列表 + 上下架开关 + 编辑/删除(新增由外壳 FAB 触发)。
class PlansTab extends ConsumerWidget {
  const PlansTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminPlansProvider);
    final groups = ref.watch(adminGroupsFullProvider).value ?? const [];
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorRetryView(
          error: e, onRetry: () => ref.invalidate(adminPlansProvider)),
      data: (plans) {
        if (plans.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(adminPlansProvider),
            child: ListView(children: [
              const SizedBox(height: 120),
              EmptyState(
                  icon: Icons.card_membership_outlined,
                  message: context.tr('adminOrders.noPlans')),
            ]),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(adminPlansProvider),
          child: ResponsiveCenter(
            maxWidth: 1100,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 90),
              itemCount: plans.length,
              itemBuilder: (context, i) => _PlanCard(
                plan: plans[i],
                group: _findGroup(groups, plans[i].groupId),
                onToggle: () => _toggleForSale(context, ref, plans[i]),
                onEdit: () => context.push('/admin/orders/plans/${plans[i].id}/edit'),
                onDelete: () => _delete(context, ref, plans[i]),
              ),
            ),
          ),
        );
      },
    );
  }

  static AdminGroup? _findGroup(List<AdminGroup> groups, int id) {
    for (final g in groups) {
      if (g.id == id) return g;
    }
    return null;
  }

  Future<void> _toggleForSale(
      BuildContext context, WidgetRef ref, SubscriptionPlan p) async {
    try {
      await ref
          .read(adminPaymentApiProvider)
          .updatePlan(p.id, {'for_sale': !p.forSale});
      ref.invalidate(adminPlansProvider);
    } catch (e) {
      if (context.mounted) showAppToast(context, '$e', error: true);
    }
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, SubscriptionPlan p) async {
    final ok = await showConfirmDialog(
      context,
      title: context.tr('adminOrders.deletePlan'),
      message: context.tr('adminOrders.deletePlanConfirm'),
      confirmLabel: context.tr('common.delete'),
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(adminPaymentApiProvider).deletePlan(p.id);
      ref.invalidate(adminPlansProvider);
      if (context.mounted) showAppToast(context, context.tr('common.done'));
    } catch (e) {
      if (context.mounted) showAppToast(context, '$e', error: true);
    }
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.group,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final SubscriptionPlan plan;
  final AdminGroup? group;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: scheme.onSurfaceVariant);
    final missing = plan.groupId > 0 && group == null;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(plan.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
              ),
              StatusPill(
                  label: plan.forSale
                      ? context.tr('adminOrders.onSale')
                      : context.tr('adminOrders.offSale'),
                  tone: plan.forSale ? StatusTone.positive : StatusTone.neutral,
                  dense: true),
              Switch(value: plan.forSale, onChanged: (_) => onToggle()),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                padding: EdgeInsets.zero,
                onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
                itemBuilder: (context) => [
                  PopupMenuItem(
                      value: 'edit',
                      height: 40,
                      child: Text(context.tr('common.edit'))),
                  PopupMenuItem(
                      value: 'delete',
                      height: 40,
                      child: Text(context.tr('common.delete'),
                          style: TextStyle(color: scheme.error))),
                ],
              ),
            ]),
            if (plan.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 2),
                child: Text(plan.description,
                    style: muted, maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 2),
              child: Wrap(spacing: 8, runSpacing: 4, children: [
                Text('\$${plan.price.toStringAsFixed(2)}',
                    style: TextStyle(
                        color: scheme.primary, fontWeight: FontWeight.w700)),
                if (plan.originalPrice != null && plan.originalPrice! > 0)
                  Text('\$${plan.originalPrice!.toStringAsFixed(2)}',
                      style: muted?.copyWith(
                          decoration: TextDecoration.lineThrough)),
                Text('·', style: muted),
                Text(
                    '${plan.validityDays} ${context.tr('adminOrders.unit_${plan.validityUnit}')}',
                    style: muted),
                Text('·', style: muted),
                if (missing)
                  _chip(context, '#${plan.groupId} ${context.tr('adminOrders.groupMissing')}',
                      scheme.errorContainer, scheme.onErrorContainer)
                else if (group != null)
                  _chip(
                      context,
                      '${group!.name} · ${group!.platform} ×${group!.rateMultiplier}',
                      scheme.secondaryContainer,
                      scheme.onSecondaryContainer),
                Text('·', style: muted),
                Text('${context.tr('adminOrders.sortOrder')} ${plan.sortOrder}',
                    style: muted),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(text,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: fg, fontWeight: FontWeight.w500)),
    );
  }
}
