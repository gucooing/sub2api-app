import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client_provider.dart';
import '../data/admin_announcements_api.dart';

final adminAnnouncementsApiProvider = Provider<AdminAnnouncementsApi>(
  (ref) => AdminAnnouncementsApi(ref.watch(apiClientProvider)),
);

@immutable
class AdminAnnouncementsState {
  const AdminAnnouncementsState({
    this.items = const [],
    this.loading = true,
    this.loadingMore = false,
    this.error,
    this.hasMore = false,
    this.page = 1,
    this.total = 0,
    this.search = '',
    this.status = '',
  });

  final List<Announcement> items;
  final bool loading;
  final bool loadingMore;
  final Object? error;
  final bool hasMore;
  final int page;
  final int total;
  final String search;
  final String status;

  AdminAnnouncementsState copyWith({
    List<Announcement>? items,
    bool? loading,
    bool? loadingMore,
    Object? error = _sentinel,
    bool? hasMore,
    int? page,
    int? total,
    String? search,
    String? status,
  }) =>
      AdminAnnouncementsState(
        items: items ?? this.items,
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        error: error == _sentinel ? this.error : error,
        hasMore: hasMore ?? this.hasMore,
        page: page ?? this.page,
        total: total ?? this.total,
        search: search ?? this.search,
        status: status ?? this.status,
      );

  static const _sentinel = Object();
}

class AdminAnnouncementsController extends Notifier<AdminAnnouncementsState> {
  @override
  AdminAnnouncementsState build() {
    Future.microtask(_loadFirst);
    return const AdminAnnouncementsState();
  }

  AdminAnnouncementsApi get _api => ref.read(adminAnnouncementsApiProvider);

  Future<void> _loadFirst() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final res = await _api.list(
        page: 1,
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

  void setStatus(String v) {
    if (v == state.status) return;
    state = state.copyWith(status: v);
    _loadFirst();
  }
}

final adminAnnouncementsControllerProvider = NotifierProvider.autoDispose<
    AdminAnnouncementsController,
    AdminAnnouncementsState>(AdminAnnouncementsController.new);

final adminAnnouncementDetailProvider =
    FutureProvider.autoDispose.family<Announcement, int>((ref, id) {
  return ref.watch(adminAnnouncementsApiProvider).getById(id);
});
