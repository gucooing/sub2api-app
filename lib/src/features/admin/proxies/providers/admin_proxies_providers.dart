import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client_provider.dart';
import '../data/admin_proxies_api.dart';

final adminProxiesApiProvider = Provider<AdminProxiesApi>(
  (ref) => AdminProxiesApi(ref.watch(apiClientProvider)),
);

@immutable
class AdminProxiesState {
  const AdminProxiesState({
    this.items = const [],
    this.loading = true,
    this.loadingMore = false,
    this.error,
    this.hasMore = false,
    this.page = 1,
    this.total = 0,
    this.search = '',
    this.protocol = '',
    this.status = '',
  });

  final List<Proxy> items;
  final bool loading;
  final bool loadingMore;
  final Object? error;
  final bool hasMore;
  final int page;
  final int total;
  final String search;
  final String protocol;
  final String status;

  int get activeFilterCount =>
      [protocol, status].where((s) => s.isNotEmpty).length;

  AdminProxiesState copyWith({
    List<Proxy>? items,
    bool? loading,
    bool? loadingMore,
    Object? error = _sentinel,
    bool? hasMore,
    int? page,
    int? total,
    String? search,
    String? protocol,
    String? status,
  }) =>
      AdminProxiesState(
        items: items ?? this.items,
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        error: error == _sentinel ? this.error : error,
        hasMore: hasMore ?? this.hasMore,
        page: page ?? this.page,
        total: total ?? this.total,
        search: search ?? this.search,
        protocol: protocol ?? this.protocol,
        status: status ?? this.status,
      );

  static const _sentinel = Object();
}

class AdminProxiesController extends Notifier<AdminProxiesState> {
  @override
  AdminProxiesState build() {
    Future.microtask(_loadFirst);
    return const AdminProxiesState();
  }

  AdminProxiesApi get _api => ref.read(adminProxiesApiProvider);

  Future<void> _loadFirst() async {
    state = state.copyWith(loading: true, error: null);
    final s = state;
    try {
      final res = await _api.list(
        page: 1,
        protocol: s.protocol,
        status: s.status,
        search: s.search,
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
    final s = state;
    try {
      final res = await _api.list(
        page: s.page + 1,
        protocol: s.protocol,
        status: s.status,
        search: s.search,
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

  void applyFilters({required String protocol, required String status}) {
    state = state.copyWith(protocol: protocol, status: status);
    _loadFirst();
  }
}

final adminProxiesControllerProvider =
    NotifierProvider.autoDispose<AdminProxiesController, AdminProxiesState>(
        AdminProxiesController.new);

/// 全部代理(供编辑页选「备用代理」)。
final adminProxiesAllListProvider =
    FutureProvider.autoDispose<List<Proxy>>((ref) {
  return ref.watch(adminProxiesApiProvider).getAll();
});
