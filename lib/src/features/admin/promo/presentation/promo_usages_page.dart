import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../i18n/app_localizations.dart';
import '../../../../shared/format/formatters.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_retry.dart';
import '../../../../shared/widgets/responsive.dart';
import '../data/admin_promo_api.dart';
import '../providers/admin_promo_providers.dart';

/// 优惠码使用记录:用户 + 赠送金额 + 使用时间,滚动加载。
class PromoUsagesPage extends ConsumerStatefulWidget {
  const PromoUsagesPage({super.key, required this.codeId});

  final int codeId;

  @override
  ConsumerState<PromoUsagesPage> createState() => _PromoUsagesPageState();
}

class _PromoUsagesPageState extends ConsumerState<PromoUsagesPage> {
  final _scroll = ScrollController();
  final List<PromoCodeUsage> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;
  int _page = 1;
  int _total = 0;
  bool _hasMore = false;

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
    super.dispose();
  }

  Future<void> _loadFirst() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res =
          await ref.read(adminPromoApiProvider).usages(widget.codeId, page: 1);
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
      final res = await ref
          .read(adminPromoApiProvider)
          .usages(widget.codeId, page: _page + 1);
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
      appBar: AppBar(title: Text(context.tr('adminPromo.usageRecords'))),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _items.isEmpty) {
      return ErrorRetryView(error: _error!, onRetry: _loadFirst);
    }
    if (_items.isEmpty) {
      return EmptyState(
          icon: Icons.history, message: context.tr('adminPromo.noUsages'));
    }
    final scheme = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: _loadFirst,
      child: ResponsiveCenter(
        maxWidth: 900,
        child: ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 24),
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
                    context.tr('adminPromo.total', params: {'n': '$_total'}),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant),
                  ),
                ),
              );
            }
            final u = _items[i];
            final when = DateTime.tryParse(u.usedAt);
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  child: Icon(Icons.person_outline,
                      color: scheme.onPrimaryContainer, size: 20),
                ),
                title: Text(u.userEmail ?? '#${u.userId}',
                    overflow: TextOverflow.ellipsis),
                subtitle: Text(
                    when == null ? u.usedAt : formatDateTime(when.toLocal())),
                trailing: Text('+${formatCost(u.bonusAmount.toDouble())}',
                    style: TextStyle(
                        color: scheme.primary, fontWeight: FontWeight.w600)),
              ),
            );
          },
        ),
      ),
    );
  }
}
