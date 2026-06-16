import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../i18n/app_localizations.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_retry.dart';
import '../../../../shared/widgets/pill_segmented.dart';
import '../../../../shared/widgets/responsive.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../data/admin_groups_api.dart';
import '../providers/admin_groups_providers.dart';

enum _GroupAction { edit, toggle, delete }

/// 分组管理(管理端底部导航分支):列表 + 搜索 + 平台/状态筛选 + 启停/删除 + 新增。
class GroupsListPage extends ConsumerStatefulWidget {
  const GroupsListPage({super.key});

  @override
  ConsumerState<GroupsListPage> createState() => _GroupsListPageState();
}

class _GroupsListPageState extends ConsumerState<GroupsListPage> {
  final _scroll = ScrollController();
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
        ref.read(adminGroupsControllerProvider.notifier).loadMore();
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
    final state = ref.watch(adminGroupsControllerProvider);
    final ctrl = ref.read(adminGroupsControllerProvider.notifier);
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab-admin-groups',
        onPressed: () => context.push('/admin/groups/new'),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          _searchBar(context, state, ctrl),
          Expanded(child: _body(context, state, ctrl)),
        ],
      ),
    );
  }

  Widget _searchBar(BuildContext context, AdminGroupsState state,
      AdminGroupsController ctrl) {
    final filterBtn = IconButton.filledTonal(
      onPressed: () => _openFilters(context, state, ctrl),
      tooltip: context.tr('adminGroups.filters'),
      icon: const Icon(Icons.tune),
    );
    return ResponsiveCenter(
      maxWidth: 1100,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
        child: SizedBox(
          height: 52,
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                onSubmitted: ctrl.setSearch,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: context.tr('adminGroups.searchHint'),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 6),
            state.activeFilterCount > 0
                ? Badge.count(count: state.activeFilterCount, child: filterBtn)
                : filterBtn,
          ]),
        ),
      ),
    );
  }

  Future<void> _openFilters(BuildContext context, AdminGroupsState state,
      AdminGroupsController ctrl) async {
    var platform = state.platform;
    var status = state.status;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(
              16, 0, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ctx.tr('adminGroups.platform'),
                  style: Theme.of(ctx).textTheme.labelLarge),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: PillSegmented<String>(
                  selected: platform,
                  onChanged: (v) => setS(() => platform = v),
                  options: const [
                    ('', '全部'),
                    ('anthropic', 'Anthropic'),
                    ('openai', 'OpenAI'),
                    ('gemini', 'Gemini'),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(ctx.tr('adminGroups.status'),
                  style: Theme.of(ctx).textTheme.labelLarge),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: PillSegmented<String>(
                  selected: status,
                  onChanged: (v) => setS(() => status = v),
                  options: [
                    ('', ctx.tr('adminGroups.all')),
                    ('active', ctx.tr('adminGroups.statusActive')),
                    ('inactive', ctx.tr('adminGroups.statusInactive')),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      platform = '';
                      status = '';
                      Navigator.pop(ctx, true);
                    },
                    child: Text(ctx.tr('adminGroups.reset')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(ctx.tr('adminGroups.apply')),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
    if (ok == true) ctrl.applyFilters(platform: platform, status: status);
  }

  Widget _body(BuildContext context, AdminGroupsState state,
      AdminGroupsController ctrl) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.items.isEmpty) {
      return ErrorRetryView(error: state.error!, onRetry: ctrl.refresh);
    }
    if (state.items.isEmpty) {
      return EmptyState(
        icon: Icons.workspaces_outline,
        message: context.tr('adminGroups.empty'),
      );
    }
    return RefreshIndicator(
      onRefresh: ctrl.refresh,
      child: ResponsiveCenter(
        maxWidth: 1100,
        child: ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(10, 2, 10, 24),
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
                    context.tr('adminGroups.total', params: {'n': '${state.total}'}),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              );
            }
            final g = state.items[i];
            return _GroupCard(
              group: g,
              onTap: () => context.push('/admin/groups/${g.id}'),
              onAction: (a) => _runAction(context, ctrl, g, a),
            );
          },
        ),
      ),
    );
  }

  Future<void> _runAction(BuildContext context, AdminGroupsController ctrl,
      AdminGroup g, _GroupAction a) async {
    final api = ref.read(adminGroupsApiProvider);
    try {
      switch (a) {
        case _GroupAction.edit:
          context.push('/admin/groups/${g.id}');
          return;
        case _GroupAction.toggle:
          await api.setStatus(g.id, !g.isActive);
        case _GroupAction.delete:
          final ok = await showConfirmDialog(
            context,
            title: context.tr('adminGroups.delete'),
            message:
                context.tr('adminGroups.deleteConfirm', params: {'name': g.name}),
            confirmLabel: context.tr('common.delete'),
            destructive: true,
          );
          if (!ok) return;
          await api.delete(g.id);
      }
      await ctrl.refresh();
      if (context.mounted) showAppToast(context, context.tr('common.done'));
    } catch (e) {
      if (context.mounted) showAppToast(context, '$e', error: true);
    }
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard(
      {required this.group, required this.onTap, required this.onAction});
  final AdminGroup group;
  final VoidCallback onTap;
  final ValueChanged<_GroupAction> onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                _badge(context, group.platform, scheme.primaryContainer,
                    scheme.onPrimaryContainer),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(group.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                ),
                if (group.isExclusive) ...[
                  _badge(context, context.tr('adminGroups.exclusive'),
                      scheme.tertiaryContainer, scheme.onTertiaryContainer),
                  const SizedBox(width: 6),
                ],
                StatusPill(
                  label: context.tr(group.isActive
                      ? 'adminGroups.statusActive'
                      : 'adminGroups.statusInactive'),
                  tone: group.isActive ? StatusTone.positive : StatusTone.neutral,
                  dense: true,
                ),
                PopupMenuButton<_GroupAction>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  padding: EdgeInsets.zero,
                  onSelected: onAction,
                  itemBuilder: (context) => [
                    PopupMenuItem(
                        value: _GroupAction.edit,
                        height: 40,
                        child: Text(context.tr('common.edit'))),
                    PopupMenuItem(
                        value: _GroupAction.toggle,
                        height: 40,
                        child: Text(context.tr(group.isActive
                            ? 'adminGroups.disable'
                            : 'adminGroups.enable'))),
                    PopupMenuItem(
                        value: _GroupAction.delete,
                        height: 40,
                        child: Text(context.tr('adminGroups.delete'),
                            style: TextStyle(color: scheme.error))),
                  ],
                ),
              ]),
              DefaultTextStyle.merge(
                style: Theme.of(context)
                    .textTheme
                    .bodySmall!
                    .copyWith(color: scheme.onSurfaceVariant),
                child: Row(children: [
                  Text('×${group.rateMultiplier}'),
                  if (group.rpmLimit != null && group.rpmLimit! > 0) ...[
                    _dot(context),
                    Text('RPM ${group.rpmLimit}'),
                  ],
                  if (group.accountCount != null) ...[
                    _dot(context),
                    Icon(Icons.dns_outlined, size: 13, color: scheme.onSurfaceVariant),
                    Text(' ${group.activeAccountCount ?? group.accountCount}/${group.accountCount}'),
                  ],
                  if (group.claudeCodeOnly) ...[
                    _dot(context),
                    const Text('Claude Code'),
                  ],
                  const SizedBox(width: 4),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dot(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text('·',
            style: TextStyle(color: Theme.of(context).colorScheme.outline)),
      );

  Widget _badge(BuildContext context, String text, Color bg, Color fg) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: fg, fontWeight: FontWeight.w600)),
      );
}
