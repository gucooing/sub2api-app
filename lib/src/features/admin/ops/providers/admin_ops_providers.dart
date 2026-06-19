import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client_provider.dart';
import '../data/admin_ops_api.dart';

final adminOpsApiProvider = Provider<AdminOpsApi>(
  (ref) => AdminOpsApi(ref.watch(apiClientProvider)),
);

final opsOverviewProvider =
    FutureProvider.autoDispose.family<OpsOverview, String>((ref, timeRange) {
  return ref.watch(adminOpsApiProvider).getOverview(timeRange: timeRange);
});

final opsAlertRulesProvider =
    FutureProvider.autoDispose<List<AlertRule>>((ref) {
  return ref.watch(adminOpsApiProvider).listAlertRules();
});

final opsAlertEventsProvider =
    FutureProvider.autoDispose<List<AlertEvent>>((ref) {
  return ref.watch(adminOpsApiProvider).listAlertEvents();
});

// ==================== 错误日志 ====================

@immutable
class OpsErrorsState {
  const OpsErrorsState({
    this.items = const [],
    this.loading = true,
    this.loadingMore = false,
    this.error,
    this.hasMore = false,
    this.page = 1,
    this.total = 0,
    this.timeRange = '24h',
    this.resolved = '',
    this.search = '',
  });

  final List<OpsErrorLog> items;
  final bool loading;
  final bool loadingMore;
  final Object? error;
  final bool hasMore;
  final int page;
  final int total;
  final String timeRange;
  final String resolved;
  final String search;

  OpsErrorsState copyWith({
    List<OpsErrorLog>? items,
    bool? loading,
    bool? loadingMore,
    Object? error = _sentinel,
    bool? hasMore,
    int? page,
    int? total,
    String? timeRange,
    String? resolved,
    String? search,
  }) =>
      OpsErrorsState(
        items: items ?? this.items,
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        error: error == _sentinel ? this.error : error,
        hasMore: hasMore ?? this.hasMore,
        page: page ?? this.page,
        total: total ?? this.total,
        timeRange: timeRange ?? this.timeRange,
        resolved: resolved ?? this.resolved,
        search: search ?? this.search,
      );

  static const _sentinel = Object();
}

class OpsErrorsController extends Notifier<OpsErrorsState> {
  @override
  OpsErrorsState build() {
    Future.microtask(_loadFirst);
    return const OpsErrorsState();
  }

  AdminOpsApi get _api => ref.read(adminOpsApiProvider);

  Future<void> _loadFirst() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final res = await _api.listErrorLogs(
        page: 1,
        timeRange: state.timeRange,
        resolved: state.resolved,
        q: state.search,
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
      final res = await _api.listErrorLogs(
        page: next,
        timeRange: state.timeRange,
        resolved: state.resolved,
        q: state.search,
      );
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

  void applyFilters({required String timeRange, required String resolved}) {
    state = state.copyWith(timeRange: timeRange, resolved: resolved);
    _loadFirst();
  }
}

final opsErrorsControllerProvider =
    NotifierProvider.autoDispose<OpsErrorsController, OpsErrorsState>(
        OpsErrorsController.new);

// ==================== 系统日志 ====================

@immutable
class OpsSystemLogsState {
  const OpsSystemLogsState({
    this.items = const [],
    this.loading = true,
    this.loadingMore = false,
    this.error,
    this.hasMore = false,
    this.page = 1,
    this.total = 0,
    this.timeRange = '1h',
    this.level = '',
    this.component = '',
    this.search = '',
  });

  final List<OpsSystemLog> items;
  final bool loading;
  final bool loadingMore;
  final Object? error;
  final bool hasMore;
  final int page;
  final int total;
  final String timeRange;
  final String level;
  final String component;
  final String search;

  OpsSystemLogsState copyWith({
    List<OpsSystemLog>? items,
    bool? loading,
    bool? loadingMore,
    Object? error = _sentinel,
    bool? hasMore,
    int? page,
    int? total,
    String? timeRange,
    String? level,
    String? component,
    String? search,
  }) =>
      OpsSystemLogsState(
        items: items ?? this.items,
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        error: error == _sentinel ? this.error : error,
        hasMore: hasMore ?? this.hasMore,
        page: page ?? this.page,
        total: total ?? this.total,
        timeRange: timeRange ?? this.timeRange,
        level: level ?? this.level,
        component: component ?? this.component,
        search: search ?? this.search,
      );

  static const _sentinel = Object();
}

class OpsSystemLogsController extends Notifier<OpsSystemLogsState> {
  @override
  OpsSystemLogsState build() {
    Future.microtask(_loadFirst);
    return const OpsSystemLogsState();
  }

  AdminOpsApi get _api => ref.read(adminOpsApiProvider);

  Future<void> _loadFirst() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final res = await _api.listSystemLogs(
        page: 1,
        timeRange: state.timeRange,
        level: state.level,
        component: state.component,
        q: state.search,
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
      final res = await _api.listSystemLogs(
        page: next,
        timeRange: state.timeRange,
        level: state.level,
        component: state.component,
        q: state.search,
      );
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

  void applyFilters({
    required String timeRange,
    required String level,
    required String component,
  }) {
    state = state.copyWith(
        timeRange: timeRange, level: level, component: component);
    _loadFirst();
  }
}

final opsSystemLogsControllerProvider = NotifierProvider.autoDispose<
    OpsSystemLogsController, OpsSystemLogsState>(OpsSystemLogsController.new);
