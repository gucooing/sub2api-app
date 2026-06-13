import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client_provider.dart';
import '../../../../shared/format/formatters.dart';
import '../../usage/providers/usage_providers.dart';
import '../data/usage_logs_api.dart';

final usageLogsApiProvider = Provider<UsageLogsApi>((ref) {
  final client = ref.watch(apiClientProvider);
  return UsageLogsApi(client);
});

/// 用户近期(90 天)用过的模型名,去重排序;供记录筛选「模型」输入联想。
final usedModelsProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final now = DateTime.now();
  final start = now.subtract(const Duration(days: 90));
  final list = await ref.watch(usageApiProvider).models(
        startDate: formatDate(start),
        endDate: formatDate(now),
      );
  final names = <String>{
    for (final m in list)
      if (m.model.isNotEmpty) m.model,
  }.toList()
    ..sort();
  return names;
});

/// 使用记录多维筛选条件。
@immutable
class UsageLogFilter {
  const UsageLogFilter({
    this.apiKeyId,
    this.groupId,
    this.model,
    this.requestType,
    this.stream,
    this.startDate,
    this.endDate,
  });

  final int? apiKeyId;
  final int? groupId;
  final String? model;

  /// 请求类型(后端 request_type 数值);null = 不限。
  final int? requestType;
  final bool? stream;
  final String? startDate;
  final String? endDate;

  /// 生效中的筛选项数量(用于筛选按钮角标)。
  int get activeCount {
    var n = 0;
    if (apiKeyId != null) n++;
    if (groupId != null) n++;
    if (model != null && model!.isNotEmpty) n++;
    if (requestType != null) n++;
    if (stream != null) n++;
    if (startDate != null || endDate != null) n++;
    return n;
  }

  @override
  bool operator ==(Object other) =>
      other is UsageLogFilter &&
      apiKeyId == other.apiKeyId &&
      groupId == other.groupId &&
      model == other.model &&
      requestType == other.requestType &&
      stream == other.stream &&
      startDate == other.startDate &&
      endDate == other.endDate;

  @override
  int get hashCode => Object.hash(
      apiKeyId, groupId, model, requestType, stream, startDate, endDate);
}

/// 使用记录列表状态(滚动加载)。
@immutable
class UsageRecordsState {
  const UsageRecordsState({
    this.items = const [],
    this.page = 0,
    this.total = 0,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.filter = const UsageLogFilter(),
  });

  final List<UsageLog> items;
  final int page;
  final int total;
  final bool isLoading;
  final bool isLoadingMore;
  final Object? error;
  final UsageLogFilter filter;

  bool get hasMore => items.length < total;
}

final usageRecordsProvider =
    NotifierProvider.autoDispose<UsageRecordsNotifier, UsageRecordsState>(
  UsageRecordsNotifier.new,
);

/// 使用记录控制器:首屏加载、滚动加载更多、应用筛选、刷新。
class UsageRecordsNotifier extends Notifier<UsageRecordsState> {
  static const _pageSize = 20;

  @override
  UsageRecordsState build() {
    Future.microtask(_loadFirst);
    return const UsageRecordsState(isLoading: true);
  }

  UsageLogsApi get _api => ref.read(usageLogsApiProvider);

  Future<PaginatedUsageLogs> _fetch(UsageLogFilter f, int page) => _api.list(
        page: page,
        pageSize: _pageSize,
        apiKeyId: f.apiKeyId,
        groupId: f.groupId,
        model: f.model,
        requestType: f.requestType,
        stream: f.stream,
        startDate: f.startDate,
        endDate: f.endDate,
      );

  Future<void> _loadFirst() async {
    final filter = state.filter;
    state = UsageRecordsState(isLoading: true, filter: filter);
    try {
      final res = await _fetch(filter, 1);
      state = UsageRecordsState(
        items: res.items,
        page: 1,
        total: res.total,
        filter: filter,
      );
    } catch (e) {
      state = UsageRecordsState(error: e, filter: filter);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    final filter = state.filter;
    state = UsageRecordsState(
      items: state.items,
      page: state.page,
      total: state.total,
      isLoadingMore: true,
      filter: filter,
    );
    try {
      final next = state.page + 1;
      final res = await _fetch(filter, next);
      state = UsageRecordsState(
        items: [...state.items, ...res.items],
        page: next,
        total: res.total,
        filter: filter,
      );
    } catch (e) {
      // 加载更多失败:保留已加载项,仅复位加载态
      state = UsageRecordsState(
        items: state.items,
        page: state.page,
        total: state.total,
        filter: filter,
      );
    }
  }

  Future<void> applyFilter(UsageLogFilter filter) async {
    state = UsageRecordsState(isLoading: true, filter: filter);
    await _loadFirst();
  }

  Future<void> refresh() => _loadFirst();
}

/// 单条使用记录详情(详情页)。
final usageLogDetailProvider =
    FutureProvider.autoDispose.family<UsageLog, int>(
  (ref, id) => ref.watch(usageLogsApiProvider).getById(id),
);
