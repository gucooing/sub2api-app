import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client_provider.dart';
import '../../../../shared/format/formatters.dart';
import '../data/admin_usage_api.dart';

final adminUsageApiProvider = Provider<AdminUsageApi>(
  (ref) => AdminUsageApi(ref.watch(apiClientProvider)),
);

/// request_type → 旧 stream 布尔(对照 web requestTypeToLegacyStream)。
bool? requestTypeToStream(String t) {
  if (t.isEmpty || t == 'unknown') return null;
  if (t == 'sync') return false;
  return true; // stream / ws_v2
}

@immutable
class AdminUsageState {
  const AdminUsageState({
    this.items = const [],
    this.stats,
    this.loading = true,
    this.loadingMore = false,
    this.error,
    this.hasMore = false,
    this.page = 1,
    this.total = 0,
    required this.startDate,
    required this.endDate,
    this.userId,
    this.userEmail = '',
    this.groupId,
    this.model = '',
    this.requestType = '',
  });

  final List<AdminUsageLog> items;
  final AdminUsageStats? stats;
  final bool loading;
  final bool loadingMore;
  final Object? error;
  final bool hasMore;
  final int page;
  final int total;
  final String startDate;
  final String endDate;
  final int? userId;
  final String userEmail;
  final int? groupId;
  final String model;
  final String requestType;

  int get activeFilterCount => [
        if (userId != null) 1,
        if (groupId != null) 1,
        if (model.isNotEmpty) 1,
        if (requestType.isNotEmpty) 1,
      ].length;

  AdminUsageState copyWith({
    List<AdminUsageLog>? items,
    AdminUsageStats? stats,
    bool? loading,
    bool? loadingMore,
    Object? error = _sentinel,
    bool? hasMore,
    int? page,
    int? total,
    String? startDate,
    String? endDate,
    int? userId = _intSentinel,
    String? userEmail,
    int? groupId = _intSentinel,
    String? model,
    String? requestType,
  }) =>
      AdminUsageState(
        items: items ?? this.items,
        stats: stats ?? this.stats,
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        error: error == _sentinel ? this.error : error,
        hasMore: hasMore ?? this.hasMore,
        page: page ?? this.page,
        total: total ?? this.total,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        userId: identical(userId, _intSentinel) ? this.userId : userId,
        userEmail: userEmail ?? this.userEmail,
        groupId: identical(groupId, _intSentinel) ? this.groupId : groupId,
        model: model ?? this.model,
        requestType: requestType ?? this.requestType,
      );

  static const _sentinel = Object();
  static const _intSentinel = -999999;
}

class AdminUsageController extends Notifier<AdminUsageState> {
  @override
  AdminUsageState build() {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 7));
    Future.microtask(_loadFirst);
    return AdminUsageState(
      startDate: formatDate(start),
      endDate: formatDate(now),
    );
  }

  AdminUsageApi get _api => ref.read(adminUsageApiProvider);

  Future<void> _loadFirst() async {
    state = state.copyWith(loading: true, error: null);
    final s = state;
    final stream = requestTypeToStream(s.requestType);
    try {
      final res = await _api.list(
        page: 1,
        userId: s.userId,
        groupId: s.groupId,
        model: s.model,
        requestType: s.requestType,
        stream: stream,
        startDate: s.startDate,
        endDate: s.endDate,
      );
      state = state.copyWith(
        items: res.items,
        loading: false,
        page: res.page,
        total: res.total,
        hasMore: res.page < res.pages,
      );
      _loadStats();
    } catch (e) {
      state = state.copyWith(loading: false, error: e);
    }
  }

  Future<void> _loadStats() async {
    final s = state;
    try {
      final stats = await _api.stats(
        userId: s.userId,
        groupId: s.groupId,
        model: s.model,
        requestType: s.requestType,
        stream: requestTypeToStream(s.requestType),
        startDate: s.startDate,
        endDate: s.endDate,
      );
      state = state.copyWith(stats: stats);
    } catch (_) {
      // 统计失败不阻塞列表
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
        userId: s.userId,
        groupId: s.groupId,
        model: s.model,
        requestType: s.requestType,
        stream: requestTypeToStream(s.requestType),
        startDate: s.startDate,
        endDate: s.endDate,
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

  void setDateRange(String start, String end) {
    state = state.copyWith(startDate: start, endDate: end);
    _loadFirst();
  }

  void applyFilters({
    required int? userId,
    required String userEmail,
    required int? groupId,
    required String model,
    required String requestType,
  }) {
    state = state.copyWith(
      userId: userId,
      userEmail: userEmail,
      groupId: groupId,
      model: model,
      requestType: requestType,
    );
    _loadFirst();
  }
}

final adminUsageControllerProvider =
    NotifierProvider.autoDispose<AdminUsageController, AdminUsageState>(
        AdminUsageController.new);
