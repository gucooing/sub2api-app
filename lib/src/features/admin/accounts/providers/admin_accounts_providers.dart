import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client_provider.dart';
import '../data/admin_accounts_api.dart';

final adminAccountsApiProvider = Provider<AdminAccountsApi>(
  (ref) => AdminAccountsApi(ref.watch(apiClientProvider)),
);

@immutable
class AdminAccountsState {
  const AdminAccountsState({
    this.items = const [],
    this.todayCost = const {},
    this.loading = true,
    this.loadingMore = false,
    this.error,
    this.hasMore = false,
    this.page = 1,
    this.total = 0,
    this.search = '',
    this.status = '',
    this.platform = '',
  });

  final List<AdminAccount> items;
  final Map<int, double> todayCost;
  final bool loading;
  final bool loadingMore;
  final Object? error;
  final bool hasMore;
  final int page;
  final int total;
  final String search;
  final String status;
  final String platform;

  AdminAccountsState copyWith({
    List<AdminAccount>? items,
    Map<int, double>? todayCost,
    bool? loading,
    bool? loadingMore,
    Object? error = _sentinel,
    bool? hasMore,
    int? page,
    int? total,
    String? search,
    String? status,
    String? platform,
  }) =>
      AdminAccountsState(
        items: items ?? this.items,
        todayCost: todayCost ?? this.todayCost,
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        error: error == _sentinel ? this.error : error,
        hasMore: hasMore ?? this.hasMore,
        page: page ?? this.page,
        total: total ?? this.total,
        search: search ?? this.search,
        status: status ?? this.status,
        platform: platform ?? this.platform,
      );

  static const _sentinel = Object();
}

class AdminAccountsController extends Notifier<AdminAccountsState> {
  @override
  AdminAccountsState build() {
    Future.microtask(_loadFirst);
    return const AdminAccountsState();
  }

  AdminAccountsApi get _api => ref.read(adminAccountsApiProvider);

  Future<void> _loadFirst() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final res = await _api.list(
        page: 1,
        platform: state.platform,
        status: state.status,
        search: state.search,
      );
      final cost = await _safeCost(res.items);
      state = state.copyWith(
        items: res.items,
        todayCost: cost,
        loading: false,
        page: res.page,
        total: res.total,
        hasMore: res.page < res.pages,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e);
    }
  }

  Future<Map<int, double>> _safeCost(List<AdminAccount> items) async {
    try {
      return await _api.batchTodayCost([for (final a in items) a.id]);
    } catch (_) {
      return const {};
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
      final cost = await _safeCost(res.items);
      state = state.copyWith(
        items: [...state.items, ...res.items],
        todayCost: {...state.todayCost, ...cost},
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

  void setStatus(String v) {
    if (v == state.status) return;
    state = state.copyWith(status: v);
    _loadFirst();
  }

  void setPlatform(String v) {
    if (v == state.platform) return;
    state = state.copyWith(platform: v);
    _loadFirst();
  }
}

final adminAccountsControllerProvider = NotifierProvider.autoDispose<
    AdminAccountsController, AdminAccountsState>(AdminAccountsController.new);

/// 单个账号详情(详情页用)。
final adminAccountDetailProvider =
    FutureProvider.autoDispose.family<AdminAccount, int>((ref, id) {
  return ref.watch(adminAccountsApiProvider).getById(id);
});
