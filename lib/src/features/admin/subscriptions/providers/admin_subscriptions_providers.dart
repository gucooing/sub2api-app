import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client_provider.dart';
import '../data/admin_subscriptions_api.dart';

final adminSubscriptionsApiProvider = Provider<AdminSubscriptionsApi>(
  (ref) => AdminSubscriptionsApi(ref.watch(apiClientProvider)),
);

@immutable
class AdminSubscriptionsState {
  const AdminSubscriptionsState({
    this.items = const [],
    this.loading = true,
    this.loadingMore = false,
    this.error,
    this.hasMore = false,
    this.page = 1,
    this.total = 0,
    this.status = '',
    this.userId,
    this.userEmail = '',
    this.groupId,
  });

  final List<AdminSubscription> items;
  final bool loading;
  final bool loadingMore;
  final Object? error;
  final bool hasMore;
  final int page;
  final int total;
  final String status;
  final int? userId;
  final String userEmail;
  final int? groupId;

  int get activeFilterCount =>
      [if (userId != null) 1, if (groupId != null) 1].length;

  AdminSubscriptionsState copyWith({
    List<AdminSubscription>? items,
    bool? loading,
    bool? loadingMore,
    Object? error = _sentinel,
    bool? hasMore,
    int? page,
    int? total,
    String? status,
    int? userId = _intSentinel,
    String? userEmail,
    int? groupId = _intSentinel,
  }) =>
      AdminSubscriptionsState(
        items: items ?? this.items,
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        error: error == _sentinel ? this.error : error,
        hasMore: hasMore ?? this.hasMore,
        page: page ?? this.page,
        total: total ?? this.total,
        status: status ?? this.status,
        userId: identical(userId, _intSentinel) ? this.userId : userId,
        userEmail: userEmail ?? this.userEmail,
        groupId: identical(groupId, _intSentinel) ? this.groupId : groupId,
      );

  static const _sentinel = Object();
  static const _intSentinel = -999999;
}

class AdminSubscriptionsController extends Notifier<AdminSubscriptionsState> {
  @override
  AdminSubscriptionsState build() {
    Future.microtask(_loadFirst);
    return const AdminSubscriptionsState();
  }

  AdminSubscriptionsApi get _api => ref.read(adminSubscriptionsApiProvider);

  Future<void> _loadFirst() async {
    state = state.copyWith(loading: true, error: null);
    final s = state;
    try {
      final res = await _api.list(
        page: 1,
        status: s.status,
        userId: s.userId,
        groupId: s.groupId,
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
        status: s.status,
        userId: s.userId,
        groupId: s.groupId,
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

  void setStatus(String v) {
    if (v == state.status) return;
    state = state.copyWith(status: v);
    _loadFirst();
  }

  void applyFilters({
    required int? userId,
    required String userEmail,
    required int? groupId,
  }) {
    state = state.copyWith(
        userId: userId, userEmail: userEmail, groupId: groupId);
    _loadFirst();
  }
}

final adminSubscriptionsControllerProvider = NotifierProvider.autoDispose<
    AdminSubscriptionsController,
    AdminSubscriptionsState>(AdminSubscriptionsController.new);

final adminSubscriptionProgressProvider = FutureProvider.autoDispose
    .family<SubscriptionProgress, int>((ref, id) {
  return ref.watch(adminSubscriptionsApiProvider).progress(id);
});
