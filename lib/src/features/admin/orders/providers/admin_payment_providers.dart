import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client_provider.dart';
import '../data/admin_payment_api.dart';

final adminPaymentApiProvider = Provider<AdminPaymentApi>(
  (ref) => AdminPaymentApi(ref.watch(apiClientProvider)),
);

// ==================== 订单列表(分页 + 筛选) ====================

@immutable
class AdminOrdersState {
  const AdminOrdersState({
    this.items = const [],
    this.loading = true,
    this.loadingMore = false,
    this.error,
    this.hasMore = false,
    this.page = 1,
    this.total = 0,
    this.search = '',
    this.status = '',
    this.paymentType = '',
    this.orderType = '',
  });

  final List<PaymentOrder> items;
  final bool loading;
  final bool loadingMore;
  final Object? error;
  final bool hasMore;
  final int page;
  final int total;
  final String search;
  final String status;
  final String paymentType;
  final String orderType;

  AdminOrdersState copyWith({
    List<PaymentOrder>? items,
    bool? loading,
    bool? loadingMore,
    Object? error = _sentinel,
    bool? hasMore,
    int? page,
    int? total,
    String? search,
    String? status,
    String? paymentType,
    String? orderType,
  }) =>
      AdminOrdersState(
        items: items ?? this.items,
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        error: error == _sentinel ? this.error : error,
        hasMore: hasMore ?? this.hasMore,
        page: page ?? this.page,
        total: total ?? this.total,
        search: search ?? this.search,
        status: status ?? this.status,
        paymentType: paymentType ?? this.paymentType,
        orderType: orderType ?? this.orderType,
      );

  static const _sentinel = Object();
}

class AdminOrdersController extends Notifier<AdminOrdersState> {
  @override
  AdminOrdersState build() {
    Future.microtask(_loadFirst);
    return const AdminOrdersState();
  }

  AdminPaymentApi get _api => ref.read(adminPaymentApiProvider);

  Future<void> _loadFirst() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final res = await _api.getOrders(
        page: 1,
        status: state.status,
        paymentType: state.paymentType,
        orderType: state.orderType,
        keyword: state.search,
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
      final res = await _api.getOrders(
        page: next,
        status: state.status,
        paymentType: state.paymentType,
        orderType: state.orderType,
        keyword: state.search,
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
    required String status,
    required String paymentType,
    required String orderType,
  }) {
    state = state.copyWith(
      status: status,
      paymentType: paymentType,
      orderType: orderType,
    );
    _loadFirst();
  }
}

final adminOrdersControllerProvider =
    NotifierProvider.autoDispose<AdminOrdersController, AdminOrdersState>(
        AdminOrdersController.new);

// ==================== 支付看板(按天数) ====================

final adminPaymentDashboardProvider = FutureProvider.autoDispose
    .family<PaymentDashboardStats, int>((ref, days) async {
  return ref.watch(adminPaymentApiProvider).getDashboard(days: days);
});

// ==================== 订阅计划 ====================

final adminPlansProvider =
    FutureProvider.autoDispose<List<SubscriptionPlan>>((ref) async {
  return ref.watch(adminPaymentApiProvider).getPlans();
});
