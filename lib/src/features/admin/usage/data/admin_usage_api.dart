import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';

/// 管理端用量统计(`GET /admin/usage/stats`,可带筛选)。
@immutable
class AdminUsageStats {
  const AdminUsageStats({
    this.totalRequests = 0,
    this.totalInputTokens = 0,
    this.totalOutputTokens = 0,
    this.totalCacheTokens = 0,
    this.totalTokens = 0,
    this.totalCost = 0,
    this.totalActualCost = 0,
    this.totalAccountCost = 0,
    this.averageDurationMs = 0,
  });

  final int totalRequests;
  final int totalInputTokens;
  final int totalOutputTokens;
  final int totalCacheTokens;
  final int totalTokens;
  final num totalCost;
  final num totalActualCost;
  final num totalAccountCost;
  final num averageDurationMs;

  factory AdminUsageStats.fromJson(Map<String, dynamic> j) => AdminUsageStats(
        totalRequests: (j['total_requests'] as num?)?.toInt() ?? 0,
        totalInputTokens: (j['total_input_tokens'] as num?)?.toInt() ?? 0,
        totalOutputTokens: (j['total_output_tokens'] as num?)?.toInt() ?? 0,
        totalCacheTokens: (j['total_cache_tokens'] as num?)?.toInt() ?? 0,
        totalTokens: (j['total_tokens'] as num?)?.toInt() ?? 0,
        totalCost: j['total_cost'] as num? ?? 0,
        totalActualCost: j['total_actual_cost'] as num? ?? 0,
        totalAccountCost: j['total_account_cost'] as num? ?? 0,
        averageDurationMs: j['average_duration_ms'] as num? ?? 0,
      );
}

/// 管理端用量日志(比用户端多账号/IP/上游模型/账号成本等字段)。
@immutable
class AdminUsageLog {
  const AdminUsageLog({
    required this.id,
    required this.userId,
    required this.model,
    this.upstreamModel,
    this.userEmail,
    this.apiKeyName,
    this.groupName,
    this.accountName,
    this.requestType,
    this.stream = false,
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.cacheCreationTokens = 0,
    this.cacheReadTokens = 0,
    this.inputCost = 0,
    this.outputCost = 0,
    this.cacheCreationCost = 0,
    this.cacheReadCost = 0,
    this.totalCost = 0,
    this.actualCost = 0,
    this.accountStatsCost,
    this.rateMultiplier = 1,
    this.accountRateMultiplier,
    this.durationMs,
    this.firstTokenMs,
    this.inboundEndpoint,
    this.upstreamEndpoint,
    this.billingMode,
    this.requestId,
    this.ipAddress,
    this.userAgent,
    this.createdAt,
  });

  final int id;
  final int userId;
  final String model;
  final String? upstreamModel;
  final String? userEmail;
  final String? apiKeyName;
  final String? groupName;
  final String? accountName;
  final String? requestType; // sync / stream / ws_v2 / unknown
  final bool stream;
  final int inputTokens;
  final int outputTokens;
  final int cacheCreationTokens;
  final int cacheReadTokens;
  final num inputCost;
  final num outputCost;
  final num cacheCreationCost;
  final num cacheReadCost;
  final num totalCost;
  final num actualCost;
  final num? accountStatsCost;
  final num rateMultiplier;
  final num? accountRateMultiplier;
  final num? durationMs;
  final num? firstTokenMs;
  final String? inboundEndpoint;
  final String? upstreamEndpoint;
  final String? billingMode;
  final String? requestId;
  final String? ipAddress;
  final String? userAgent;
  final String? createdAt;

  int get totalTokens =>
      inputTokens + outputTokens + cacheCreationTokens + cacheReadTokens;

  /// 解析请求类型(对照 web resolveUsageRequestType)。
  String get resolvedType {
    const valid = {'unknown', 'sync', 'stream', 'ws_v2'};
    if (requestType != null && valid.contains(requestType)) return requestType!;
    return stream ? 'stream' : 'sync';
  }

  /// 账号实际成本(account_stats_cost ?? total_cost) × 账号倍率。
  num get accountCost =>
      (accountStatsCost ?? totalCost) * (accountRateMultiplier ?? 1);

  factory AdminUsageLog.fromJson(Map<String, dynamic> j) => AdminUsageLog(
        id: (j['id'] as num?)?.toInt() ?? 0,
        userId: (j['user_id'] as num?)?.toInt() ?? 0,
        model: j['model'] as String? ?? '',
        upstreamModel: j['upstream_model'] as String?,
        userEmail: (j['user'] as Map?)?['email'] as String?,
        apiKeyName: (j['api_key'] as Map?)?['name'] as String?,
        groupName: (j['group'] as Map?)?['name'] as String?,
        accountName: (j['account'] as Map?)?['name'] as String?,
        requestType: j['request_type'] as String?,
        stream: j['stream'] as bool? ?? false,
        inputTokens: (j['input_tokens'] as num?)?.toInt() ?? 0,
        outputTokens: (j['output_tokens'] as num?)?.toInt() ?? 0,
        cacheCreationTokens: (j['cache_creation_tokens'] as num?)?.toInt() ?? 0,
        cacheReadTokens: (j['cache_read_tokens'] as num?)?.toInt() ?? 0,
        inputCost: j['input_cost'] as num? ?? 0,
        outputCost: j['output_cost'] as num? ?? 0,
        cacheCreationCost: j['cache_creation_cost'] as num? ?? 0,
        cacheReadCost: j['cache_read_cost'] as num? ?? 0,
        totalCost: j['total_cost'] as num? ?? 0,
        actualCost: j['actual_cost'] as num? ?? 0,
        accountStatsCost: j['account_stats_cost'] as num?,
        rateMultiplier: j['rate_multiplier'] as num? ?? 1,
        accountRateMultiplier: j['account_rate_multiplier'] as num?,
        durationMs: j['duration_ms'] as num?,
        firstTokenMs: j['first_token_ms'] as num?,
        inboundEndpoint: j['inbound_endpoint'] as String?,
        upstreamEndpoint: j['upstream_endpoint'] as String?,
        billingMode: j['billing_mode'] as String?,
        requestId: j['request_id'] as String?,
        ipAddress: j['ip_address'] as String?,
        userAgent: j['user_agent'] as String?,
        createdAt: j['created_at'] as String?,
      );
}

@immutable
class AdminUsageLogPage {
  const AdminUsageLogPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pages,
  });

  final List<AdminUsageLog> items;
  final int total;
  final int page;
  final int pages;

  factory AdminUsageLogPage.fromJson(Map<String, dynamic> json) {
    final list = json['items'] as List? ?? const [];
    return AdminUsageLogPage(
      items: list
          .whereType<Map>()
          .map((e) => AdminUsageLog.fromJson(e.cast<String, dynamic>()))
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pages: (json['pages'] as num?)?.toInt() ?? 1,
    );
  }
}

/// 简易用户(用户筛选搜索结果)。
@immutable
class UsageSimpleUser {
  const UsageSimpleUser(
      {required this.id, required this.email, this.deleted = false});
  final int id;
  final String email;
  final bool deleted;

  factory UsageSimpleUser.fromJson(Map<String, dynamic> j) => UsageSimpleUser(
        id: (j['id'] as num?)?.toInt() ?? 0,
        email: j['email'] as String? ?? '',
        deleted: j['deleted'] as bool? ?? false,
      );
}

/// 用量清理任务。
@immutable
class UsageCleanupTask {
  const UsageCleanupTask({
    required this.id,
    required this.status,
    this.deletedRows = 0,
    this.errorMessage,
    this.startTime,
    this.endTime,
    this.createdAt,
    this.startedAt,
    this.finishedAt,
  });

  final int id;
  final String status; // pending / running / completed / failed / canceled
  final int deletedRows;
  final String? errorMessage;
  final String? startTime;
  final String? endTime;
  final String? createdAt;
  final String? startedAt;
  final String? finishedAt;

  bool get isActive => status == 'pending' || status == 'running';

  factory UsageCleanupTask.fromJson(Map<String, dynamic> j) {
    final filters = (j['filters'] as Map?)?.cast<String, dynamic>();
    return UsageCleanupTask(
      id: (j['id'] as num?)?.toInt() ?? 0,
      status: j['status'] as String? ?? 'pending',
      deletedRows: (j['deleted_rows'] as num?)?.toInt() ?? 0,
      errorMessage: j['error_message'] as String?,
      startTime: filters?['start_time'] as String?,
      endTime: filters?['end_time'] as String?,
      createdAt: j['created_at'] as String?,
      startedAt: j['started_at'] as String?,
      finishedAt: j['finished_at'] as String?,
    );
  }
}

@immutable
class UsageCleanupTaskPage {
  const UsageCleanupTaskPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pages,
  });

  final List<UsageCleanupTask> items;
  final int total;
  final int page;
  final int pages;

  factory UsageCleanupTaskPage.fromJson(Map<String, dynamic> json) {
    final list = json['items'] as List? ?? const [];
    return UsageCleanupTaskPage(
      items: list
          .whereType<Map>()
          .map((e) => UsageCleanupTask.fromJson(e.cast<String, dynamic>()))
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pages: (json['pages'] as num?)?.toInt() ?? 1,
    );
  }
}

/// 管理端用量 API(对照 web api/admin/usage.ts)。
class AdminUsageApi {
  AdminUsageApi(this._client);

  final ApiClient _client;

  Map<String, dynamic> _filterParams({
    int? userId,
    int? groupId,
    String? model,
    String? requestType,
    bool? stream,
    String? startDate,
    String? endDate,
  }) =>
      {
        'user_id': ?userId,
        'group_id': ?groupId,
        if (model != null && model.isNotEmpty) 'model': model,
        if (requestType != null && requestType.isNotEmpty)
          'request_type': requestType,
        'stream': ?stream,
        if (startDate != null && startDate.isNotEmpty) 'start_date': startDate,
        if (endDate != null && endDate.isNotEmpty) 'end_date': endDate,
      };

  Future<AdminUsageLogPage> list({
    int page = 1,
    int pageSize = 20,
    int? userId,
    int? groupId,
    String? model,
    String? requestType,
    bool? stream,
    String? startDate,
    String? endDate,
    String sortBy = 'created_at',
    String sortOrder = 'desc',
  }) async {
    final data = await _client.get<dynamic>('/admin/usage', query: {
      'page': page,
      'page_size': pageSize,
      ..._filterParams(
        userId: userId,
        groupId: groupId,
        model: model,
        requestType: requestType,
        stream: stream,
        startDate: startDate,
        endDate: endDate,
      ),
      'sort_by': sortBy,
      'sort_order': sortOrder,
    });
    return AdminUsageLogPage.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<AdminUsageStats> stats({
    int? userId,
    int? groupId,
    String? model,
    String? requestType,
    bool? stream,
    String? startDate,
    String? endDate,
  }) async {
    final data = await _client.get<dynamic>('/admin/usage/stats',
        query: _filterParams(
          userId: userId,
          groupId: groupId,
          model: model,
          requestType: requestType,
          stream: stream,
          startDate: startDate,
          endDate: endDate,
        ));
    return AdminUsageStats.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<List<UsageSimpleUser>> searchUsers(String q) async {
    final data =
        await _client.get<dynamic>('/admin/usage/search-users', query: {'q': q});
    final list = (data as List?) ?? const [];
    return [
      for (final e in list)
        if (e is Map) UsageSimpleUser.fromJson(e.cast<String, dynamic>()),
    ];
  }

  Future<UsageCleanupTaskPage> cleanupTasks(
      {int page = 1, int pageSize = 20}) async {
    final data = await _client.get<dynamic>('/admin/usage/cleanup-tasks',
        query: {'page': page, 'page_size': pageSize});
    return UsageCleanupTaskPage.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<UsageCleanupTask> createCleanupTask({
    required String startDate,
    required String endDate,
    int? userId,
    int? groupId,
    String? model,
    String? requestType,
    bool? stream,
  }) async {
    final data =
        await _client.post<dynamic>('/admin/usage/cleanup-tasks', data: {
      'start_date': startDate,
      'end_date': endDate,
      'user_id': ?userId,
      'group_id': ?groupId,
      if (model != null && model.isNotEmpty) 'model': model,
      if (requestType != null && requestType.isNotEmpty)
        'request_type': requestType,
      'stream': ?stream,
    });
    return UsageCleanupTask.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<void> cancelCleanupTask(int id) =>
      _client.post<dynamic>('/admin/usage/cleanup-tasks/$id/cancel');
}
