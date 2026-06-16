import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client_provider.dart';
import '../data/admin_monitor_api.dart';

final adminMonitorApiProvider = Provider<AdminChannelMonitorApi>(
  (ref) => AdminChannelMonitorApi(ref.watch(apiClientProvider)),
);

@immutable
class AdminMonitorState {
  const AdminMonitorState({
    this.items = const [],
    this.loading = true,
    this.loadingMore = false,
    this.error,
    this.hasMore = false,
    this.page = 1,
    this.total = 0,
    this.search = '',
    this.provider = '',
  });

  final List<ChannelMonitor> items;
  final bool loading;
  final bool loadingMore;
  final Object? error;
  final bool hasMore;
  final int page;
  final int total;
  final String search;
  final String provider;

  int get activeFilterCount => provider.isEmpty ? 0 : 1;

  AdminMonitorState copyWith({
    List<ChannelMonitor>? items,
    bool? loading,
    bool? loadingMore,
    Object? error = _sentinel,
    bool? hasMore,
    int? page,
    int? total,
    String? search,
    String? provider,
  }) =>
      AdminMonitorState(
        items: items ?? this.items,
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        error: error == _sentinel ? this.error : error,
        hasMore: hasMore ?? this.hasMore,
        page: page ?? this.page,
        total: total ?? this.total,
        search: search ?? this.search,
        provider: provider ?? this.provider,
      );

  static const _sentinel = Object();
}

class AdminMonitorController extends Notifier<AdminMonitorState> {
  @override
  AdminMonitorState build() {
    Future.microtask(_loadFirst);
    return const AdminMonitorState();
  }

  AdminChannelMonitorApi get _api => ref.read(adminMonitorApiProvider);

  Future<void> _loadFirst() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final res = await _api.list(
          page: 1, provider: state.provider, search: state.search);
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
          page: next, provider: state.provider, search: state.search);
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

  void setProvider(String p) {
    state = state.copyWith(provider: p);
    _loadFirst();
  }
}

final adminMonitorControllerProvider =
    NotifierProvider.autoDispose<AdminMonitorController, AdminMonitorState>(
        AdminMonitorController.new);

final adminMonitorDetailProvider =
    FutureProvider.autoDispose.family<ChannelMonitor, int>((ref, id) {
  return ref.watch(adminMonitorApiProvider).getById(id);
});

final adminMonitorHistoryProvider =
    FutureProvider.autoDispose.family<List<MonitorCheckItem>, int>((ref, id) {
  return ref.watch(adminMonitorApiProvider).history(id);
});
