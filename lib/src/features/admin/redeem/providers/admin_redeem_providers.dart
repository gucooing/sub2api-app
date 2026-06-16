import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client_provider.dart';
import '../data/admin_redeem_api.dart';

final adminRedeemApiProvider = Provider<AdminRedeemApi>(
  (ref) => AdminRedeemApi(ref.watch(apiClientProvider)),
);

@immutable
class AdminRedeemState {
  const AdminRedeemState({
    this.items = const [],
    this.loading = true,
    this.loadingMore = false,
    this.error,
    this.hasMore = false,
    this.page = 1,
    this.total = 0,
    this.search = '',
    this.type = '',
    this.status = '',
  });

  final List<RedeemCode> items;
  final bool loading;
  final bool loadingMore;
  final Object? error;
  final bool hasMore;
  final int page;
  final int total;
  final String search;
  final String type;
  final String status;

  int get activeFilterCount => [type, status].where((s) => s.isNotEmpty).length;

  AdminRedeemState copyWith({
    List<RedeemCode>? items,
    bool? loading,
    bool? loadingMore,
    Object? error = _sentinel,
    bool? hasMore,
    int? page,
    int? total,
    String? search,
    String? type,
    String? status,
  }) =>
      AdminRedeemState(
        items: items ?? this.items,
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        error: error == _sentinel ? this.error : error,
        hasMore: hasMore ?? this.hasMore,
        page: page ?? this.page,
        total: total ?? this.total,
        search: search ?? this.search,
        type: type ?? this.type,
        status: status ?? this.status,
      );

  static const _sentinel = Object();
}

class AdminRedeemController extends Notifier<AdminRedeemState> {
  @override
  AdminRedeemState build() {
    Future.microtask(_loadFirst);
    return const AdminRedeemState();
  }

  AdminRedeemApi get _api => ref.read(adminRedeemApiProvider);

  Future<void> _loadFirst() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final res = await _api.list(
        page: 1,
        type: state.type,
        status: state.status,
        search: state.search,
      );
      state = state.copyWith(
        items: res.items,
        loading: false,
        page: res.page,
        total: res.total,
        hasMore: res.page < res.pages,
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
      final res = await _api.list(
        page: next,
        type: state.type,
        status: state.status,
        search: state.search,
      );
      state = state.copyWith(
        items: [...state.items, ...res.items],
        loadingMore: false,
        page: res.page,
        hasMore: res.page < res.pages,
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

  void applyFilters({required String type, required String status}) {
    state = state.copyWith(type: type, status: status);
    _loadFirst();
  }
}

final adminRedeemControllerProvider =
    NotifierProvider.autoDispose<AdminRedeemController, AdminRedeemState>(
        AdminRedeemController.new);

final adminRedeemStatsProvider =
    FutureProvider.autoDispose<RedeemStats>((ref) {
  return ref.watch(adminRedeemApiProvider).stats();
});
