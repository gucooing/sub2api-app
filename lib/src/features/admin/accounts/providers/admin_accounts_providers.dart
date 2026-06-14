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
    this.type = '',
    this.group = '',
    this.privacyMode = '',
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
  final String type;
  final String group;
  final String privacyMode;

  /// 已启用的非空筛选数量(用于「筛选」按钮角标)。
  int get activeFilterCount =>
      [status, platform, type, group, privacyMode].where((s) => s.isNotEmpty).length;

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
    String? type,
    String? group,
    String? privacyMode,
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
        type: type ?? this.type,
        group: group ?? this.group,
        privacyMode: privacyMode ?? this.privacyMode,
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
        type: state.type,
        status: state.status,
        group: state.group,
        privacyMode: state.privacyMode,
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
        type: state.type,
        status: state.status,
        group: state.group,
        privacyMode: state.privacyMode,
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

  /// 一次性应用「更多筛选」弹层的选择。
  void applyFilters({
    required String status,
    required String platform,
    required String type,
    required String group,
    required String privacyMode,
  }) {
    state = state.copyWith(
      status: status,
      platform: platform,
      type: type,
      group: group,
      privacyMode: privacyMode,
    );
    _loadFirst();
  }

  void clearFilters() {
    state = state.copyWith(
        status: '', platform: '', type: '', group: '', privacyMode: '');
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

/// 全部分组(id+name),供筛选与编辑选择;不分页。
final adminGroupsAllProvider =
    FutureProvider.autoDispose<List<({int id, String name})>>((ref) {
  return ref.watch(adminAccountsApiProvider).groupsAll();
});

/// 全部代理(id+name),供编辑选择。
final adminProxiesAllProvider =
    FutureProvider.autoDispose<List<({int id, String name})>>((ref) {
  return ref.watch(adminAccountsApiProvider).proxiesAll();
});
