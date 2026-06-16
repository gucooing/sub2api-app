import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../i18n/app_localizations.dart';
import '../../../../shared/format/formatters.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../shared/widgets/error_retry.dart';
import '../../../../shared/widgets/pill_segmented.dart';
import '../../../../shared/widgets/responsive.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../data/admin_users_api.dart';
import '../providers/admin_users_providers.dart';

/// 用户详情:全量信息 + 余额调整 + 启停 + 编辑(并发/RPM/角色/备注)+ 余额历史。
class UserDetailPage extends ConsumerWidget {
  const UserDetailPage({super.key, required this.userId});

  final int userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminUserDetailProvider(userId));
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('adminUsers.detailTitle'))),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorRetryView(
          error: e,
          onRetry: () => ref.invalidate(adminUserDetailProvider(userId)),
        ),
        data: (u) => _content(context, ref, u),
      ),
    );
  }

  void _refresh(WidgetRef ref) {
    ref.invalidate(adminUserDetailProvider(userId));
    ref.invalidate(adminUserBalanceHistoryProvider(userId));
    ref.invalidate(adminUsersControllerProvider);
  }

  Widget _content(BuildContext context, WidgetRef ref, AdminUser u) {
    return ResponsiveCenter(
      maxWidth: 720,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // 头部:用户名/邮箱 + 角色 + 状态
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(u.username.isEmpty ? u.email : u.username,
                      style: Theme.of(context).textTheme.titleLarge),
                  if (u.username.isNotEmpty)
                    Text(u.email,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            if (u.isAdmin) ...[
              Chip(
                label: Text(context.tr('adminUsers.roleAdmin')),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 6),
            ],
            StatusPill(
              label: context.tr(u.isActive
                  ? 'adminUsers.statusActive'
                  : 'adminUsers.statusDisabled'),
              tone: u.isActive ? StatusTone.positive : StatusTone.neutral,
            ),
          ]),
          const SizedBox(height: 12),

          // 余额卡
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr('adminUsers.balance'),
                        style: Theme.of(context).textTheme.bodySmall),
                    Text(formatCost(u.balance.toDouble()),
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w700)),
                  ],
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: () => _adjustBalance(context, ref, u),
                  icon: const Icon(Icons.account_balance_wallet_outlined,
                      size: 18),
                  label: Text(context.tr('adminUsers.adjustBalance')),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 8),

          // 信息
          SectionHeader(title: context.tr('adminUsers.sec.info')),
          _kv(context, 'adminUsers.kConcurrency',
              '${u.currentConcurrency}/${u.concurrency}'),
          _kv(context, 'adminUsers.kRpm',
              (u.rpmLimit == null || u.rpmLimit == 0) ? '∞' : '${u.rpmLimit}'),
          _kv(context, 'adminUsers.kRole',
              context.tr(u.isAdmin ? 'adminUsers.roleAdmin' : 'adminUsers.roleUser')),
          _kv(context, 'adminUsers.kGroups',
              u.allowedGroups == null
                  ? context.tr('adminUsers.allGroups')
                  : (u.allowedGroups!.isEmpty
                      ? '-'
                      : u.allowedGroups!.join(', '))),
          if ((u.notes ?? '').isNotEmpty)
            _kv(context, 'adminUsers.kNotes', u.notes!),
          if (u.createdAt != null)
            _kv(context, 'adminUsers.kCreated', u.createdAt!),
          if (u.lastActiveAt != null)
            _kv(context, 'adminUsers.kLastActive', u.lastActiveAt!),

          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _editUser(context, ref, u),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(context.tr('common.edit')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _toggleStatus(context, ref, u),
                icon: Icon(u.isActive ? Icons.block : Icons.check_circle_outline,
                    size: 18),
                label: Text(context.tr(
                    u.isActive ? 'adminUsers.disable' : 'adminUsers.enable')),
              ),
            ),
          ]),

          const SizedBox(height: 16),
          SectionHeader(title: context.tr('adminUsers.sec.history')),
          _history(context, ref),
        ],
      ),
    );
  }

  Widget _history(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminUserBalanceHistoryProvider(userId));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Text('$e',
          style: TextStyle(color: Theme.of(context).colorScheme.error)),
      data: (page) {
        if (page.items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Text(context.tr('adminUsers.noHistory'),
                style: Theme.of(context).textTheme.bodySmall),
          );
        }
        return Column(
          children: [
            for (final h in page.items) _historyTile(context, h),
          ],
        );
      },
    );
  }

  Widget _historyTile(BuildContext context, BalanceHistoryItem h) {
    final scheme = Theme.of(context).colorScheme;
    final positive = h.value >= 0;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(h.notes?.isNotEmpty == true ? h.notes! : h.type),
      subtitle: Text('${h.type}${h.createdAt != null ? ' · ${h.createdAt}' : ''}',
          style: Theme.of(context).textTheme.bodySmall),
      trailing: Text(
        '${positive ? '+' : ''}${formatCost(h.value.toDouble())}',
        style: TextStyle(
          color: positive ? const Color(0xFF4ADE80) : scheme.error,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _kv(BuildContext context, String labelKey, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(context.tr(labelKey),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(value,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  // ===== 操作 =====

  Future<void> _adjustBalance(
      BuildContext context, WidgetRef ref, AdminUser u) async {
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    var op = 'add';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('adminUsers.adjustBalance')),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StatefulBuilder(
                builder: (ctx, setS) => Align(
                  alignment: Alignment.centerLeft,
                  child: PillSegmented<String>(
                    selected: op,
                    onChanged: (v) => setS(() => op = v),
                    options: [
                      ('add', ctx.tr('adminUsers.opAdd')),
                      ('subtract', ctx.tr('adminUsers.opSubtract')),
                      ('set', ctx.tr('adminUsers.opSet')),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: ctx.tr('adminUsers.amount'),
                  prefixText: '\$ ',
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                decoration: InputDecoration(
                  labelText: ctx.tr('adminUsers.notesOptional'),
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.tr('common.cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.tr('common.save'))),
        ],
      ),
    );
    if (ok != true) return;
    final amount = num.tryParse(amountCtrl.text.trim());
    if (amount == null) {
      if (context.mounted) {
        showAppToast(context, context.tr('adminUsers.invalidAmount'),
            error: true);
      }
      return;
    }
    try {
      await ref.read(adminUsersApiProvider).updateBalance(u.id,
          balance: amount, operation: op, notes: notesCtrl.text.trim());
      _refresh(ref);
      if (context.mounted) showAppToast(context, context.tr('common.done'));
    } catch (e) {
      if (context.mounted) showAppToast(context, '$e', error: true);
    }
  }

  Future<void> _toggleStatus(
      BuildContext context, WidgetRef ref, AdminUser u) async {
    try {
      await ref.read(adminUsersApiProvider).setStatus(u.id, !u.isActive);
      _refresh(ref);
      if (context.mounted) showAppToast(context, context.tr('common.done'));
    } catch (e) {
      if (context.mounted) showAppToast(context, '$e', error: true);
    }
  }

  Future<void> _editUser(
      BuildContext context, WidgetRef ref, AdminUser u) async {
    final concCtrl = TextEditingController(text: '${u.concurrency}');
    final rpmCtrl = TextEditingController(text: '${u.rpmLimit ?? 0}');
    final notesCtrl = TextEditingController(text: u.notes ?? '');
    var role = u.role;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('adminUsers.editTitle')),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StatefulBuilder(
                builder: (ctx, setS) => Align(
                  alignment: Alignment.centerLeft,
                  child: PillSegmented<String>(
                    selected: role,
                    onChanged: (v) => setS(() => role = v),
                    options: [
                      ('user', ctx.tr('adminUsers.roleUser')),
                      ('admin', ctx.tr('adminUsers.roleAdmin')),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: concCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: ctx.tr('adminUsers.kConcurrency'),
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: rpmCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: ctx.tr('adminUsers.kRpm'),
                  helperText: ctx.tr('adminUsers.rpmHint'),
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                decoration: InputDecoration(
                  labelText: ctx.tr('adminUsers.kNotes'),
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.tr('common.cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.tr('common.save'))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(adminUsersApiProvider).update(u.id, {
        'role': role,
        'concurrency': int.tryParse(concCtrl.text.trim()) ?? u.concurrency,
        'rpm_limit': int.tryParse(rpmCtrl.text.trim()) ?? 0,
        'notes': notesCtrl.text.trim(),
      });
      _refresh(ref);
      if (context.mounted) showAppToast(context, context.tr('common.done'));
    } catch (e) {
      if (context.mounted) showAppToast(context, '$e', error: true);
    }
  }
}
