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
import '../data/admin_channels_api.dart';
import '../providers/admin_channels_providers.dart';

enum _Action { edit, delete }

const _statuses = ['', 'active', 'disabled'];

/// 渠道管理:列表 + 状态筛选 + 搜索 + 新增/编辑/删除(对照 web ChannelsView 核心)。
class ChannelsListPage extends ConsumerStatefulWidget {
  const ChannelsListPage({super.key});

  @override
  ConsumerState<ChannelsListPage> createState() => _ChannelsListPageState();
}

class _ChannelsListPageState extends ConsumerState<ChannelsListPage> {
  final _scroll = ScrollController();
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
        ref.read(adminChannelsControllerProvider.notifier).loadMore();
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
    final state = ref.watch(adminChannelsControllerProvider);
    final ctrl = ref.read(adminChannelsControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('adminChannels.title'))),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-admin-channels',
        onPressed: () async {
          await context.push('/admin/channels/new');
          ctrl.refresh();
        },
        icon: const Icon(Icons.add),
        label: Text(context.tr('adminChannels.create')),
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
                  hintText: context.tr('adminChannels.searchHint'),
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
                            ? context.tr('adminChannels.allStatus')
                            : context.tr('adminChannels.status_$s')),
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

  Widget _body(BuildContext context, AdminChannelsState state,
      AdminChannelsController ctrl) {
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
              icon: Icons.price_change_outlined,
              message: context.tr('adminChannels.empty')),
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
                    context.tr('adminChannels.total',
                        params: {'n': '${state.total}'}),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              );
            }
            return _ChannelCard(
              channel: state.items[i],
              onAction: (a) => _runAction(context, ctrl, state.items[i], a),
              onTap: () async {
                await context.push('/admin/channels/${state.items[i].id}/edit');
                ctrl.refresh();
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _runAction(BuildContext context, AdminChannelsController ctrl,
      Channel c, _Action a) async {
    switch (a) {
      case _Action.edit:
        await context.push('/admin/channels/${c.id}/edit');
        ctrl.refresh();
      case _Action.delete:
        final ok = await showConfirmDialog(
          context,
          title: context.tr('adminChannels.delete'),
          message: context.tr('adminChannels.deleteConfirm'),
          confirmLabel: context.tr('common.delete'),
          destructive: true,
        );
        if (!ok) return;
        try {
          await ref.read(adminChannelsApiProvider).delete(c.id);
          await ctrl.refresh();
          if (context.mounted) showAppToast(context, context.tr('common.done'));
        } catch (e) {
          if (context.mounted) showAppToast(context, '$e', error: true);
        }
    }
  }
}

class _ChannelCard extends StatelessWidget {
  const _ChannelCard(
      {required this.channel, required this.onAction, required this.onTap});
  final Channel channel;
  final ValueChanged<_Action> onAction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tone =
        channel.status == 'active' ? StatusTone.positive : StatusTone.neutral;
    final platforms = {for (final p in channel.modelPricing) p.platform}
        .where((e) => e.isNotEmpty)
        .join(', ');
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(channel.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                ),
                StatusPill(
                    label: context.tr('adminChannels.status_${channel.status}'),
                    tone: tone,
                    dense: true),
                PopupMenuButton<_Action>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  padding: EdgeInsets.zero,
                  onSelected: onAction,
                  itemBuilder: (context) => [
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
              if (channel.description.isNotEmpty)
                Text(channel.description,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(
                '${context.tr('adminChannels.groupsCount', params: {
                      'n': '${channel.groupIds.length}'
                    })}'
                '  ·  ${context.tr('adminChannels.pricingCount', params: {
                      'n': '${channel.modelPricing.length}'
                    })}'
                '${platforms.isEmpty ? '' : '  ·  $platforms'}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
