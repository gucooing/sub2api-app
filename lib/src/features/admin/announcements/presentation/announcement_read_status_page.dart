import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../i18n/app_localizations.dart';
import '../../../../shared/format/formatters.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_retry.dart';
import '../../../../shared/widgets/responsive.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../data/admin_announcements_api.dart';
import '../providers/admin_announcements_providers.dart';

/// 公告阅读情况:可见用户列表(邮箱/用户名/余额/是否命中/已读时间) + 搜索 + 滚动加载。
class AnnouncementReadStatusPage extends ConsumerStatefulWidget {
  const AnnouncementReadStatusPage({super.key, required this.announcementId});

  final int announcementId;

  @override
  ConsumerState<AnnouncementReadStatusPage> createState() =>
      _AnnouncementReadStatusPageState();
}

class _AnnouncementReadStatusPageState
    extends ConsumerState<AnnouncementReadStatusPage> {
  final _scroll = ScrollController();
  final _searchCtrl = TextEditingController();

  final List<AnnouncementReadStatus> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;
  int _page = 1;
  int _total = 0;
  bool _hasMore = false;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
        _loadMore();
      }
    });
    _loadFirst();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFirst() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref.read(adminAnnouncementsApiProvider).readStatus(
            widget.announcementId,
            page: 1,
            search: _search,
          );
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(res.items);
        _loading = false;
        _page = res.page;
        _total = res.total;
        _hasMore = res.page < res.pages;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final res = await ref.read(adminAnnouncementsApiProvider).readStatus(
            widget.announcementId,
            page: _page + 1,
            search: _search,
          );
      if (!mounted) return;
      setState(() {
        _items.addAll(res.items);
        _loadingMore = false;
        _page = res.page;
        _hasMore = res.page < res.pages;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('adminAnnouncements.readStatus'))),
      body: Column(
        children: [
          ResponsiveCenter(
            maxWidth: 900,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
              child: TextField(
                controller: _searchCtrl,
                textInputAction: TextInputAction.search,
                onSubmitted: (v) {
                  _search = v;
                  _loadFirst();
                },
                decoration: InputDecoration(
                  hintText: context.tr('adminAnnouncements.searchUsers'),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          ),
          Expanded(child: _body(context)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _items.isEmpty) {
      return ErrorRetryView(error: _error!, onRetry: _loadFirst);
    }
    if (_items.isEmpty) {
      return EmptyState(
        icon: Icons.group_outlined,
        message: context.tr('adminAnnouncements.noUsers'),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadFirst,
      child: ResponsiveCenter(
        maxWidth: 900,
        child: ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(10, 2, 10, 24),
          itemCount: _items.length + 1,
          itemBuilder: (context, i) {
            if (i == _items.length) {
              if (_loadingMore) {
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
                        params: {'n': '$_total'}),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              );
            }
            return _row(context, _items[i]);
          },
        ),
      ),
    );
  }

  Widget _row(BuildContext context, AnnouncementReadStatus u) {
    final scheme = Theme.of(context).colorScheme;
    final read = u.readAt != null && u.readAt!.isNotEmpty;
    final readLabel = read
        ? (DateTime.tryParse(u.readAt!) != null
            ? formatDateTime(DateTime.parse(u.readAt!).toLocal())
            : u.readAt!)
        : context.tr('adminAnnouncements.unread');
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(u.email,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    '${u.username.isEmpty ? '-' : u.username}  ·  ${formatCost(u.balance.toDouble())}  ·  $readLabel',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusPill(
              label: u.eligible
                  ? context.tr('adminAnnouncements.eligible')
                  : context.tr('common.no'),
              tone: u.eligible ? StatusTone.positive : StatusTone.neutral,
              dense: true,
            ),
          ],
        ),
      ),
    );
  }
}
