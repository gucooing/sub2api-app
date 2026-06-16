import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client_provider.dart';
import '../data/admin_users_api.dart';

final adminUsersApiProvider = Provider<AdminUsersApi>(
  (ref) => AdminUsersApi(ref.watch(apiClientProvider)),
);

@immutable
class AdminUsersState {
  const AdminUsersState({
    this.items = const [],
    this.loading = true,
    this.loadingMore = false,
    this.error,
    this.hasMore = false,
    this.page = 1,
    this.total = 0,
    this.search = '',
    this.status = '',
    this.role = '',
  });

  final List<AdminUser> items;
  final bool loading;
  final bool loadingMore;
  final Object? error;
  final bool hasMore;
  final int page;
  final int total;
  final String search;
  final String status;
  final String role;

  int get activeFilterCount =>
      [status, role].where((s) => s.isNotEmpty).length;

  AdminUsersState copyWith({
    List<AdminUser>? items,
    bool? loading,
    bool? loadingMore,
    Object? error = _sentinel,
    bool? hasMore,
    int? page,
    int? total,
    String? search,
    String? status,
    String? role,
  }) =>
      AdminUsersState(
        items: items ?? this.items,
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        error: error == _sentinel ? this.error : error,
        hasMore: hasMore ?? this.hasMore,
        page: page ?? this.page,
        total: total ?? this.total,
        search: search ?? this.search,
        status: status ?? this.status,
        role: role ?? this.role,
      );

  static const _sentinel = Object();
}

class AdminUsersController extends Notifier<AdminUsersState> {
  @override
  AdminUsersState build() {
    Future.microtask(_loadFirst);
    return const AdminUsersState();
  }

  AdminUsersApi get _api => ref.read(adminUsersApiProvider);

  Future<void> _loadFirst() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final res = await _api.list(
        page: 1,
        status: state.status,
        role: state.role,
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
        status: state.status,
        role: state.role,
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

  void applyFilters({required String status, required String role}) {
    state = state.copyWith(status: status, role: role);
    _loadFirst();
  }

  void clearFilters() {
    state = state.copyWith(status: '', role: '');
    _loadFirst();
  }
}

final adminUsersControllerProvider =
    NotifierProvider.autoDispose<AdminUsersController, AdminUsersState>(
        AdminUsersController.new);

/// 单个用户详情。
final adminUserDetailProvider =
    FutureProvider.autoDispose.family<AdminUser, int>((ref, id) {
  return ref.watch(adminUsersApiProvider).getById(id);
});

/// 用户余额历史(首页)。
final adminUserBalanceHistoryProvider =
    FutureProvider.autoDispose.family<BalanceHistoryPage, int>((ref, id) {
  return ref.watch(adminUsersApiProvider).balanceHistory(id);
});
