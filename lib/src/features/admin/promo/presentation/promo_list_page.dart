import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/server/server_store.dart';
import '../../../../i18n/app_localizations.dart';
import '../../../../shared/format/formatters.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../../shared/widgets/date_time_field.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_retry.dart';
import '../../../../shared/widgets/responsive.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../data/admin_promo_api.dart';
import '../providers/admin_promo_providers.dart';

enum _Action { copy, registerLink, usages, edit, delete }

const _statuses = ['', 'active', 'disabled'];

/// 优惠码管理:列表 + 状态筛选 + 搜索 + 新增/编辑/删除 + 复制注册链接 + 使用记录(对照 web)。
class PromoListPage extends ConsumerStatefulWidget {
  const PromoListPage({super.key});

  @override
  ConsumerState<PromoListPage> createState() => _PromoListPageState();
}

class _PromoListPageState extends ConsumerState<PromoListPage> {
  final _scroll = ScrollController();
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
        ref.read(adminPromoControllerProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminPromoControllerProvider);
    final ctrl = ref.read(adminPromoControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('adminPromo.title'))),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-admin-promo',
        onPressed: () => _edit(context),
        icon: const Icon(Icons.add),
        label: Text(context.tr('adminPromo.create')),
      ),
      body: Column(
        children: [
          ResponsiveCenter(
            maxWidth: 1100,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
              child: TextField(
                controller: _searchCtrl,
                onSubmitted: ctrl.setSearch,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: context.tr('adminPromo.searchHint'),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          ),
          ResponsiveCenter(
            maxWidth: 1100,
            child: SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                children: [
                  for (final s in _statuses)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(s.isEmpty
                            ? context.tr('adminPromo.allStatus')
                            : context.tr('adminPromo.status_$s')),
                        selected: state.status == s,
                        onSelected: (_) => ctrl.setStatus(s),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(child: _body(context, state, ctrl)),
        ],
      ),
    );
  }

  Widget _body(
      BuildContext context, AdminPromoState state, AdminPromoController ctrl) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.items.isEmpty) {
      return ErrorRetryView(error: state.error!, onRetry: ctrl.refresh);
    }
    if (state.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: ctrl.refresh,
        child: ListView(children: [
          const SizedBox(height: 120),
          EmptyState(
              icon: Icons.local_offer_outlined,
              message: context.tr('adminPromo.empty')),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: ctrl.refresh,
      child: ResponsiveCenter(
        maxWidth: 1100,
        child: ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 24),
          itemCount: state.items.length + 1,
          itemBuilder: (context, i) {
            if (i == state.items.length) {
              if (state.loadingMore) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Center(
                  child: Text(
                    context
                        .tr('adminPromo.total', params: {'n': '${state.total}'}),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              );
            }
            return _Card(
              code: state.items[i],
              onAction: (a) => _runAction(context, ctrl, state.items[i], a),
            );
          },
        ),
      ),
    );
  }

  Future<void> _runAction(BuildContext context, AdminPromoController ctrl,
      PromoCode c, _Action a) async {
    switch (a) {
      case _Action.copy:
        await Clipboard.setData(ClipboardData(text: c.code));
        if (context.mounted) {
          showAppToast(context, context.tr('adminPromo.copied'));
        }
      case _Action.registerLink:
        final origin = ref.read(activeServerProvider).baseUrl;
        final link = '$origin/register?promo=${Uri.encodeComponent(c.code)}';
        await Clipboard.setData(ClipboardData(text: link));
        if (context.mounted) {
          showAppToast(context, context.tr('adminPromo.linkCopied'));
        }
      case _Action.usages:
        context.push('/admin/promo-codes/${c.id}/usages');
      case _Action.edit:
        await _edit(context, existing: c);
      case _Action.delete:
        final ok = await showConfirmDialog(
          context,
          title: context.tr('adminPromo.delete'),
          message: context.tr('adminPromo.deleteConfirm'),
          confirmLabel: context.tr('common.delete'),
          destructive: true,
        );
        if (!ok) return;
        try {
          await ref.read(adminPromoApiProvider).delete(c.id);
          await ctrl.refresh();
          if (context.mounted) showAppToast(context, context.tr('common.done'));
        } catch (e) {
          if (context.mounted) showAppToast(context, '$e', error: true);
        }
    }
  }

  Future<void> _edit(BuildContext context, {PromoCode? existing}) async {
    final isEdit = existing != null;
    final codeCtrl = TextEditingController(text: existing?.code ?? '');
    final bonusCtrl =
        TextEditingController(text: existing?.bonusAmount.toString() ?? '1');
    final maxUsesCtrl =
        TextEditingController(text: existing?.maxUses.toString() ?? '0');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    var status = existing?.status ?? 'active';
    DateTime? expiresAt = existing?.expiresAt == null
        ? null
        : DateTime.tryParse(existing!.expiresAt!)?.toLocal();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr(isEdit ? 'adminPromo.editTitle' : 'adminPromo.create')),
        content: SizedBox(
          width: 360,
          child: StatefulBuilder(
            builder: (ctx, setS) => SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                  controller: codeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: ctx.tr('adminPromo.code'),
                    helperText:
                        isEdit ? null : ctx.tr('adminPromo.codeAutoHint'),
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bonusCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: ctx.tr('adminPromo.bonusAmount'),
                    prefixText: '\$ ',
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: maxUsesCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: ctx.tr('adminPromo.maxUses'),
                    helperText: ctx.tr('adminPromo.zeroUnlimited'),
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
                if (isEdit) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: ctx.tr('adminPromo.status'),
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      for (final s in ['active', 'disabled'])
                        DropdownMenuItem(
                            value: s, child: Text(ctx.tr('adminPromo.status_$s'))),
                    ],
                    onChanged: (v) => setS(() => status = v ?? 'active'),
                  ),
                ],
                const SizedBox(height: 12),
                DateTimeField(
                  label: ctx.tr('adminPromo.expiresAt'),
                  emptyHint: ctx.tr('adminPromo.neverExpires'),
                  value: expiresAt,
                  onChanged: (d) => setS(() => expiresAt = d),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: ctx.tr('adminPromo.notes'),
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ]),
            ),
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
    final bonus = num.tryParse(bonusCtrl.text.trim());
    if (bonus == null) {
      if (context.mounted) {
        showAppToast(context, context.tr('adminPromo.errBonus'), error: true);
      }
      return;
    }
    final maxUses = int.tryParse(maxUsesCtrl.text.trim()) ?? 0;
    final unix =
        expiresAt == null ? null : expiresAt!.millisecondsSinceEpoch ~/ 1000;
    try {
      final api = ref.read(adminPromoApiProvider);
      if (isEdit) {
        await api.update(
          existing.id,
          code: codeCtrl.text.trim(),
          bonusAmount: bonus,
          maxUses: maxUses,
          status: status,
          expiresAt: unix ?? 0,
          notes: notesCtrl.text.trim(),
        );
      } else {
        await api.create(
          code: codeCtrl.text.trim(),
          bonusAmount: bonus,
          maxUses: maxUses,
          expiresAt: unix,
          notes: notesCtrl.text.trim(),
        );
      }
      await ref.read(adminPromoControllerProvider.notifier).refresh();
      if (context.mounted) showAppToast(context, context.tr('common.done'));
    } catch (e) {
      if (context.mounted) showAppToast(context, '$e', error: true);
    }
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.code, required this.onAction});
  final PromoCode code;
  final ValueChanged<_Action> onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final eff = code.effectiveStatus(DateTime.now());
    final tone = switch (eff) {
      'active' => StatusTone.positive,
      'expired' => StatusTone.danger,
      _ => StatusTone.neutral,
    };
    final maxLabel = code.maxUses == 0 ? '∞' : '${code.maxUses}';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(code.code,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600, fontFamily: 'monospace'),
                    overflow: TextOverflow.ellipsis),
              ),
              StatusPill(
                  label: context.tr('adminPromo.status_$eff'),
                  tone: tone,
                  dense: true),
              PopupMenuButton<_Action>(
                icon: const Icon(Icons.more_vert, size: 20),
                padding: EdgeInsets.zero,
                onSelected: onAction,
                itemBuilder: (context) => [
                  PopupMenuItem(
                      value: _Action.copy,
                      height: 40,
                      child: Text(context.tr('adminPromo.copy'))),
                  PopupMenuItem(
                      value: _Action.registerLink,
                      height: 40,
                      child: Text(context.tr('adminPromo.copyRegisterLink'))),
                  PopupMenuItem(
                      value: _Action.usages,
                      height: 40,
                      child: Text(context.tr('adminPromo.viewUsages'))),
                  PopupMenuItem(
                      value: _Action.edit,
                      height: 40,
                      child: Text(context.tr('common.edit'))),
                  PopupMenuItem(
                      value: _Action.delete,
                      height: 40,
                      child: Text(context.tr('common.delete'),
                          style: TextStyle(color: scheme.error))),
                ],
              ),
            ]),
            DefaultTextStyle.merge(
              style: Theme.of(context)
                  .textTheme
                  .bodySmall!
                  .copyWith(color: scheme.onSurfaceVariant),
              child: Wrap(spacing: 6, runSpacing: 2, children: [
                Text('+${formatCost(code.bonusAmount.toDouble())}',
                    style: TextStyle(
                        color: scheme.primary, fontWeight: FontWeight.w600)),
                Text('·'),
                Text('${context.tr('adminPromo.used')} ${code.usedCount}/$maxLabel'),
                if (code.expiresAt != null && code.expiresAt!.isNotEmpty) ...[
                  Text('·'),
                  Text(
                      '${context.tr('adminPromo.expiresAt')} ${_fmt(code.expiresAt)}'),
                ],
                if (code.notes != null && code.notes!.isNotEmpty) ...[
                  Text('·'),
                  Text(code.notes!),
                ],
              ]),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final d = DateTime.tryParse(raw);
    return d == null ? raw : formatDateTime(d.toLocal());
  }
}
