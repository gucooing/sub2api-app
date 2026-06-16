import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../i18n/app_localizations.dart';
import '../../../../shared/format/formatters.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_retry.dart';
import '../../../../shared/widgets/pill_segmented.dart';
import '../../../../shared/widgets/responsive.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../data/admin_users_api.dart';
import '../providers/admin_users_providers.dart';

/// 用户管理(管理端底部导航分支):紧凑列表 + 搜索 + 状态/角色筛选 + 进详情。
class UsersListPage extends ConsumerStatefulWidget {
  const UsersListPage({super.key});

  @override
  ConsumerState<UsersListPage> createState() => _UsersListPageState();
}

class _UsersListPageState extends ConsumerState<UsersListPage> {
  final _scroll = ScrollController();
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
        ref.read(adminUsersControllerProvider.notifier).loadMore();
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
    final state = ref.watch(adminUsersControllerProvider);
    final ctrl = ref.read(adminUsersControllerProvider.notifier);
    return Scaffold(
      body: Column(
        children: [
          _searchBar(context, state, ctrl),
          Expanded(child: _body(context, state, ctrl)),
        ],
      ),
    );
  }

  Widget _searchBar(
      BuildContext context, AdminUsersState state, AdminUsersController ctrl) {
    final filterBtn = IconButton.filledTonal(
      onPressed: () => _openFilters(context, state, ctrl),
      tooltip: context.tr('adminUsers.filters'),
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
                  hintText: context.tr('adminUsers.searchHint'),
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

  Future<void> _openFilters(
      BuildContext context, AdminUsersState state, AdminUsersController ctrl) async {
    var status = state.status;
    var role = state.role;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              16, 0, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ctx.tr('adminUsers.status'),
                  style: Theme.of(ctx).textTheme.labelLarge),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: PillSegmented<String>(
                  selected: status,
                  onChanged: (v) => setSheet(() => status = v),
                  options: [
                    ('', ctx.tr('adminUsers.all')),
                    ('active', ctx.tr('adminUsers.statusActive')),
                    ('disabled', ctx.tr('adminUsers.statusDisabled')),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(ctx.tr('adminUsers.role'),
                  style: Theme.of(ctx).textTheme.labelLarge),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: PillSegmented<String>(
                  selected: role,
                  onChanged: (v) => setSheet(() => role = v),
                  options: [
                    ('', ctx.tr('adminUsers.all')),
                    ('admin', ctx.tr('adminUsers.roleAdmin')),
                    ('user', ctx.tr('adminUsers.roleUser')),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      status = '';
                      role = '';
                      Navigator.pop(ctx, true);
                    },
                    child: Text(ctx.tr('adminUsers.reset')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(ctx.tr('adminUsers.apply')),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
    if (ok == true) ctrl.applyFilters(status: status, role: role);
  }

  Widget _body(
      BuildContext context, AdminUsersState state, AdminUsersController ctrl) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.items.isEmpty) {
      return ErrorRetryView(error: state.error!, onRetry: ctrl.refresh);
    }
    if (state.items.isEmpty) {
      return EmptyState(
        icon: Icons.people_outline,
        message: context.tr('adminUsers.empty'),
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
                    context.tr('adminUsers.total', params: {'n': '${state.total}'}),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              );
            }
            final u = state.items[i];
            return _UserCard(
              user: u,
              onTap: () => context.push('/admin/users/${u.id}'),
            );
          },
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user, required this.onTap});
  final AdminUser user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(
                    user.username.isEmpty ? user.email : user.username,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (user.isAdmin) ...[
                  _badge(context, context.tr('adminUsers.roleAdmin'),
                      scheme.tertiaryContainer, scheme.onTertiaryContainer),
                  const SizedBox(width: 6),
                ],
                StatusPill(
                  label: context.tr(user.isActive
                      ? 'adminUsers.statusActive'
                      : 'adminUsers.statusDisabled'),
                  tone: user.isActive ? StatusTone.positive : StatusTone.neutral,
                  dense: true,
                ),
              ]),
              const SizedBox(height: 4),
              DefaultTextStyle.merge(
                style: Theme.of(context)
                    .textTheme
                    .bodySmall!
                    .copyWith(color: scheme.onSurfaceVariant),
                child: Row(children: [
                  Flexible(
                    child: Text(user.email, overflow: TextOverflow.ellipsis),
                  ),
                  _dot(context),
                  Icon(Icons.bolt_outlined, size: 13, color: scheme.onSurfaceVariant),
                  Text(' ${user.currentConcurrency}/${user.concurrency}'),
                  if (user.rpmLimit != null && user.rpmLimit! > 0) ...[
                    _dot(context),
                    Text('RPM ${user.rpmLimit}'),
                  ],
                  const Spacer(),
                  Text(
                    formatCost(user.balance.toDouble()),
                    style: TextStyle(
                        color: scheme.primary, fontWeight: FontWeight.w600),
                  ),
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
