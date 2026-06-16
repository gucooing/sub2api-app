import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client_provider.dart';
import '../data/admin_groups_api.dart';

final adminGroupsApiProvider = Provider<AdminGroupsApi>(
  (ref) => AdminGroupsApi(ref.watch(apiClientProvider)),
);

@immutable
class AdminGroupsState {
  const AdminGroupsState({
    this.items = const [],
    this.loading = true,
    this.loadingMore = false,
    this.error,
    this.hasMore = false,
    this.page = 1,
    this.total = 0,
    this.search = '',
    this.platform = '',
    this.status = '',
  });

  final List<AdminGroup> items;
  final bool loading;
  final bool loadingMore;
  final Object? error;
  final bool hasMore;
  final int page;
  final int total;
  final String search;
  final String platform;
  final String status;

  int get activeFilterCount =>
      [platform, status].where((s) => s.isNotEmpty).length;

  AdminGroupsState copyWith({
    List<AdminGroup>? items,
    bool? loading,
    bool? loadingMore,
    Object? error = _sentinel,
    bool? hasMore,
    int? page,
    int? total,
    String? search,
    String? platform,
    String? status,
  }) =>
      AdminGroupsState(
        items: items ?? this.items,
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        error: error == _sentinel ? this.error : error,
        hasMore: hasMore ?? this.hasMore,
        page: page ?? this.page,
        total: total ?? this.total,
        search: search ?? this.search,
        platform: platform ?? this.platform,
        status: status ?? this.status,
      );

  static const _sentinel = Object();
}

class AdminGroupsController extends Notifier<AdminGroupsState> {
  @override
  AdminGroupsState build() {
    Future.microtask(_loadFirst);
    return const AdminGroupsState();
  }

  AdminGroupsApi get _api => ref.read(adminGroupsApiProvider);

  Future<void> _loadFirst() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final res = await _api.list(
        page: 1,
        platform: state.platform,
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
        platform: state.platform,
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

  void applyFilters({required String platform, required String status}) {
    state = state.copyWith(platform: platform, status: status);
    _loadFirst();
  }
}

final adminGroupsControllerProvider =
    NotifierProvider.autoDispose<AdminGroupsController, AdminGroupsState>(
        AdminGroupsController.new);

final adminGroupDetailProvider =
    FutureProvider.autoDispose.family<AdminGroup, int>((ref, id) {
  return ref.watch(adminGroupsApiProvider).getById(id);
});

final adminGroupRatesProvider =
    FutureProvider.autoDispose.family<List<GroupRateEntry>, int>((ref, id) {
  return ref.watch(adminGroupsApiProvider).rateMultipliers(id);
});
