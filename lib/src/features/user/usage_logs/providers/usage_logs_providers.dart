import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client_provider.dart';
import '../data/usage_logs_api.dart';

final usageLogsApiProvider = Provider<UsageLogsApi>((ref) {
  final client = ref.watch(apiClientProvider);
  return UsageLogsApi(client);
});

/// 使用记录列表提供者(支持分页)。
final usageLogsProvider = FutureProvider.autoDispose
    .family<PaginatedUsageLogs, UsageLogsParams>((ref, params) async {
  final api = ref.watch(usageLogsApiProvider);
  return await api.list(
    page: params.page,
    pageSize: params.pageSize,
    apiKeyId: params.apiKeyId,
  );
});

/// 使用记录查询参数。
class UsageLogsParams {
  const UsageLogsParams({
    this.page = 1,
    this.pageSize = 20,
    this.apiKeyId,
  });

  final int page;
  final int pageSize;
  final int? apiKeyId;

  UsageLogsParams copyWith({
    int? page,
    int? pageSize,
    int? apiKeyId,
  }) {
    return UsageLogsParams(
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      apiKeyId: apiKeyId ?? this.apiKeyId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UsageLogsParams &&
          runtimeType == other.runtimeType &&
          page == other.page &&
          pageSize == other.pageSize &&
          apiKeyId == other.apiKeyId;

  @override
  int get hashCode => Object.hash(page, pageSize, apiKeyId);
}
