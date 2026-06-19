import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../i18n/app_localizations.dart';
import '../../../../shared/format/formatters.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_retry.dart';
import '../../../../shared/widgets/responsive.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../data/admin_announcements_api.dart';
import '../providers/admin_announcements_providers.dart';

enum _Action { readStatus, edit, delete }

const _statuses = ['', 'draft', 'active', 'archived'];

/// 公告管理:列表 + 状态筛选 + 搜索 + 新增/编辑/删除 + 阅读情况(对照 web AnnouncementsView)。
class AnnouncementsListPage extends ConsumerStatefulWidget {
  const AnnouncementsListPage({super.key});

  @override
  ConsumerState<AnnouncementsListPage> createState() =>
      _AnnouncementsListPageState();
}

class _AnnouncementsListPageState extends ConsumerState<AnnouncementsListPage> {
  final _scroll = ScrollController();
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
        ref.read(adminAnnouncementsControllerProvider.notifier).loadMore();
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
    final state = ref.watch(adminAnnouncementsControllerProvider);
    final ctrl = ref.read(adminAnnouncementsControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('adminAnnouncements.title'))),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-admin-announcements',
        onPressed: () async {
          await context.push('/admin/announcements-admin/new');
          ctrl.refresh();
        },
        icon: const Icon(Icons.add),
        label: Text(context.tr('adminAnnouncements.create')),
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
                  hintText: context.tr('adminAnnouncements.searchHint'),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          ),
          _statusBar(context, state, ctrl),
          Expanded(child: _body(context, state, ctrl)),
        ],
      ),
    );
  }

  Widget _statusBar(BuildContext context, AdminAnnouncementsState state,
      AdminAnnouncementsController ctrl) {
    return ResponsiveCenter(
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
                      ? context.tr('adminAnnouncements.allStatus')
                      : context.tr('adminAnnouncements.status_$s')),
                  selected: state.status == s,
                  onSelected: (_) => ctrl.setStatus(s),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, AdminAnnouncementsState state,
      AdminAnnouncementsController ctrl) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.items.isEmpty) {
      return ErrorRetryView(error: state.error!, onRetry: ctrl.refresh);
    }
    if (state.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: ctrl.refresh,
        child: ListView(
          children: [
            const SizedBox(height: 120),
            EmptyState(
              icon: Icons.campaign_outlined,
              message: context.tr('adminAnnouncements.empty'),
            ),
          ],
        ),
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
                    context.tr('adminAnnouncements.total',
                        params: {'n': '${state.total}'}),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              );
            }
            return _Card(
              a: state.items[i],
              onAction: (act) => _runAction(context, ctrl, state.items[i], act),
            );
          },
        ),
      ),
    );
  }

  Future<void> _runAction(BuildContext context,
      AdminAnnouncementsController ctrl, Announcement a, _Action act) async {
    switch (act) {
      case _Action.readStatus:
        context.push('/admin/announcements-admin/${a.id}/read-status');
      case _Action.edit:
        await context.push('/admin/announcements-admin/${a.id}/edit');
        ctrl.refresh();
      case _Action.delete:
        final ok = await showConfirmDialog(
          context,
          title: context.tr('adminAnnouncements.delete'),
          message: context.tr('adminAnnouncements.deleteConfirm'),
          confirmLabel: context.tr('common.delete'),
          destructive: true,
        );
        if (!ok) return;
        try {
          await ref.read(adminAnnouncementsApiProvider).delete(a.id);
          await ctrl.refresh();
          if (context.mounted) showAppToast(context, context.tr('common.done'));
        } catch (e) {
          if (context.mounted) showAppToast(context, '$e', error: true);
        }
    }
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.a, required this.onAction});
  final Announcement a;
  final ValueChanged<_Action> onAction;

  StatusTone get _tone => switch (a.status) {
        'active' => StatusTone.positive,
        'archived' => StatusTone.warning,
        _ => StatusTone.neutral,
      };

  String _fmt(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final d = DateTime.tryParse(raw);
    return d == null ? raw : formatDateTime(d.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isPopup = a.notifyMode == 'popup';
    final start = _fmt(a.startsAt);
    final end = _fmt(a.endsAt);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    a.title,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                StatusPill(
                    label: context.tr('adminAnnouncements.status_${a.status}'),
                    tone: _tone,
                    dense: true),
                PopupMenuButton<_Action>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  padding: EdgeInsets.zero,
                  onSelected: onAction,
                  itemBuilder: (context) => [
                    PopupMenuItem(
                        value: _Action.readStatus,
                        height: 40,
                        child: Text(context.tr('adminAnnouncements.readStatus'))),
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
              ],
            ),
            Wrap(
              spacing: 6,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _MiniChip(
                  label: context.tr(isPopup
                      ? 'adminAnnouncements.notify_popup'
                      : 'adminAnnouncements.notify_silent'),
                  tone: isPopup ? scheme.tertiary : scheme.outline,
                ),
                Text('#${a.id}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant)),
                Text(
                  a.targeting.isAll
                      ? context.tr('adminAnnouncements.targetAll')
                      : context.tr('adminAnnouncements.targetCustom',
                          params: {'n': '${a.targeting.anyOf.length}'}),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
            if (start.isNotEmpty || end.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '${context.tr('adminAnnouncements.startsAt')}: ${start.isEmpty ? context.tr('adminAnnouncements.immediate') : start}'
                '  ·  ${context.tr('adminAnnouncements.endsAt')}: ${end.isEmpty ? context.tr('adminAnnouncements.never') : end}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label, required this.tone});
  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: tone, fontWeight: FontWeight.w600)),
    );
  }
}
