import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client_provider.dart';
import '../data/admin_affiliates_api.dart';

final adminAffiliatesApiProvider = Provider<AdminAffiliatesApi>(
  (ref) => AdminAffiliatesApi(ref.watch(apiClientProvider)),
);

enum AffiliateRecordType { invites, rebates, transfers }

@immutable
class AffiliateRecordsState {
  const AffiliateRecordsState({
    this.items = const [],
    this.loading = true,
    this.loadingMore = false,
    this.error,
    this.hasMore = false,
    this.page = 1,
    this.total = 0,
    this.search = '',
    this.startAt = '',
    this.endAt = '',
    this.sortBy = 'created_at',
    this.sortOrder = 'desc',
  });

  final List<Object> items;
  final bool loading;
  final bool loadingMore;
  final Object? error;
  final bool hasMore;
  final int page;
  final int total;
  final String search;
  final String startAt;
  final String endAt;
  final String sortBy;
  final String sortOrder;

  AffiliateRecordsState copyWith({
    List<Object>? items,
    bool? loading,
    bool? loadingMore,
    Object? error = _sentinel,
    bool? hasMore,
    int? page,
    int? total,
    String? search,
    String? startAt,
    String? endAt,
    String? sortBy,
    String? sortOrder,
  }) =>
      AffiliateRecordsState(
        items: items ?? this.items,
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        error: error == _sentinel ? this.error : error,
        hasMore: hasMore ?? this.hasMore,
        page: page ?? this.page,
        total: total ?? this.total,
        search: search ?? this.search,
        startAt: startAt ?? this.startAt,
        endAt: endAt ?? this.endAt,
        sortBy: sortBy ?? this.sortBy,
        sortOrder: sortOrder ?? this.sortOrder,
      );

  static const _sentinel = Object();
}

class AffiliateRecordsController extends Notifier<AffiliateRecordsState> {
  AffiliateRecordsController(this.type);

  final AffiliateRecordType type;

  @override
  AffiliateRecordsState build() {
    Future.microtask(_loadFirst);
    return const AffiliateRecordsState();
  }

  AdminAffiliatesApi get _api => ref.read(adminAffiliatesApiProvider);

  Future<({List<Object> items, int total, int pages})> _fetch(int page) async {
    switch (type) {
      case AffiliateRecordType.invites:
        final r = await _api.listInvites(
            page: page,
            search: state.search,
            startAt: state.startAt,
            endAt: state.endAt,
            sortBy: state.sortBy,
            sortOrder: state.sortOrder);
        return (items: r.items.cast<Object>(), total: r.total, pages: r.pages);
      case AffiliateRecordType.rebates:
        final r = await _api.listRebates(
            page: page,
            search: state.search,
            startAt: state.startAt,
            endAt: state.endAt,
            sortBy: state.sortBy,
            sortOrder: state.sortOrder);
        return (items: r.items.cast<Object>(), total: r.total, pages: r.pages);
      case AffiliateRecordType.transfers:
        final r = await _api.listTransfers(
            page: page,
            search: state.search,
            startAt: state.startAt,
            endAt: state.endAt,
            sortBy: state.sortBy,
            sortOrder: state.sortOrder);
        return (items: r.items.cast<Object>(), total: r.total, pages: r.pages);
    }
  }

  Future<void> _loadFirst() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final res = await _fetch(1);
      state = state.copyWith(
        items: res.items,
        loading: false,
        page: 1,
        total: res.total,
        hasMore: 1 < res.pages,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e);
    }
  }

  Future<void> refresh() => _loadFirst();

  Future<void> loadMore() async {
    if (state.loadingMore || !state.hasMore) return;
    state = state.copyWith(loadingMore: true);
    try {
      final next = state.page + 1;
      final res = await _fetch(next);
      state = state.copyWith(
        items: [...state.items, ...res.items],
        loadingMore: false,
        page: next,
        hasMore: next < res.pages,
      );
    } catch (_) {
      state = state.copyWith(loadingMore: false);
    }
  }

  void setSearch(String v) {
    if (v == state.search) return;
    state = state.copyWith(search: v);
    _loadFirst();
  }

  void applyFilters({required String startAt, required String endAt}) {
    state = state.copyWith(startAt: startAt, endAt: endAt);
    _loadFirst();
  }

  void setSort(String sortBy, String sortOrder) {
    state = state.copyWith(sortBy: sortBy, sortOrder: sortOrder);
    _loadFirst();
  }
}

final adminAffiliateInvitesProvider = NotifierProvider.autoDispose<
        AffiliateRecordsController, AffiliateRecordsState>(
    () => AffiliateRecordsController(AffiliateRecordType.invites));

final adminAffiliateRebatesProvider = NotifierProvider.autoDispose<
        AffiliateRecordsController, AffiliateRecordsState>(
    () => AffiliateRecordsController(AffiliateRecordType.rebates));

final adminAffiliateTransfersProvider = NotifierProvider.autoDispose<
        AffiliateRecordsController, AffiliateRecordsState>(
    () => AffiliateRecordsController(AffiliateRecordType.transfers));

/// 用户邀请返利概览(按需拉取)。
final affiliateUserOverviewProvider = FutureProvider.autoDispose
    .family<AffiliateUserOverview, int>((ref, userId) async {
  return ref.watch(adminAffiliatesApiProvider).getUserOverview(userId);
});
