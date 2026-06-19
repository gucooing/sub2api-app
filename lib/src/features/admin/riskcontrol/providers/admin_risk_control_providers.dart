import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client_provider.dart';
import '../data/admin_risk_control_api.dart';

final adminRiskControlApiProvider = Provider<AdminRiskControlApi>(
  (ref) => AdminRiskControlApi(ref.watch(apiClientProvider)),
);

final riskControlConfigProvider =
    FutureProvider.autoDispose<ContentModerationConfig>((ref) async {
  return ref.watch(adminRiskControlApiProvider).getConfig();
});

final riskControlStatusProvider =
    FutureProvider.autoDispose<ContentModerationStatus>((ref) async {
  return ref.watch(adminRiskControlApiProvider).getStatus();
});

@immutable
class ModerationLogsState {
  const ModerationLogsState({
    this.items = const [],
    this.loading = true,
    this.loadingMore = false,
    this.error,
    this.hasMore = false,
    this.page = 1,
    this.total = 0,
    this.result = '',
    this.groupId = 0,
    this.endpoint = '',
    this.search = '',
    this.from = '',
    this.to = '',
  });

  final List<ModerationLog> items;
  final bool loading;
  final bool loadingMore;
  final Object? error;
  final bool hasMore;
  final int page;
  final int total;
  final String result;
  final int groupId;
  final String endpoint;
  final String search;
  final String from;
  final String to;

  ModerationLogsState copyWith({
    List<ModerationLog>? items,
    bool? loading,
    bool? loadingMore,
    Object? error = _sentinel,
    bool? hasMore,
    int? page,
    int? total,
    String? result,
    int? groupId,
    String? endpoint,
    String? search,
    String? from,
    String? to,
  }) =>
      ModerationLogsState(
        items: items ?? this.items,
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        error: error == _sentinel ? this.error : error,
        hasMore: hasMore ?? this.hasMore,
        page: page ?? this.page,
        total: total ?? this.total,
        result: result ?? this.result,
        groupId: groupId ?? this.groupId,
        endpoint: endpoint ?? this.endpoint,
        search: search ?? this.search,
        from: from ?? this.from,
        to: to ?? this.to,
      );

  static const _sentinel = Object();
}

class ModerationLogsController extends Notifier<ModerationLogsState> {
  @override
  ModerationLogsState build() {
    Future.microtask(_loadFirst);
    return const ModerationLogsState();
  }

  AdminRiskControlApi get _api => ref.read(adminRiskControlApiProvider);

  Future<void> _loadFirst() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final res = await _api.listLogs(
        page: 1,
        result: state.result,
        groupId: state.groupId,
        endpoint: state.endpoint,
        search: state.search,
        from: state.from,
        to: state.to,
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
      final res = await _api.listLogs(
        page: next,
        result: state.result,
        groupId: state.groupId,
        endpoint: state.endpoint,
        search: state.search,
        from: state.from,
        to: state.to,
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

  void applyFilters({
    required String result,
    required int groupId,
    required String endpoint,
    required String from,
    required String to,
  }) {
    state = state.copyWith(
        result: result,
        groupId: groupId,
        endpoint: endpoint,
        from: from,
        to: to);
    _loadFirst();
  }

  /// 解封后就地更新该用户所有日志行的状态。
  void markUserStatus(int userId, String status) {
    state = state.copyWith(items: [
      for (final log in state.items)
        if (log.userId == userId) log.copyWithUserStatus(status) else log,
    ]);
  }
}

final moderationLogsControllerProvider =
    NotifierProvider.autoDispose<ModerationLogsController, ModerationLogsState>(
        ModerationLogsController.new);
