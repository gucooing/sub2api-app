import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';

/// 内容审核风险阈值默认值(百分比 0-100,对照 web riskThresholdDefaults)。
const Map<String, num> kRiskThresholdDefaults = {
  'harassment': 98,
  'harassment/threatening': 90,
  'hate': 65,
  'hate/threatening': 65,
  'illicit': 95,
  'illicit/violent': 95,
  'self-harm': 65,
  'self-harm/intent': 85,
  'self-harm/instructions': 65,
  'sexual': 65,
  'sexual/minors': 65,
  'violence': 95,
  'violence/graphic': 95,
};

const List<String> kModerationModes = ['pre_block', 'observe', 'off'];
const List<String> kKeywordBlockingModes = [
  'keyword_and_api',
  'keyword_only',
  'api_only'
];
const List<String> kModelFilterTypes = ['all', 'include', 'exclude'];

@immutable
class ModelFilter {
  const ModelFilter({this.type = 'all', this.models = const []});
  final String type;
  final List<String> models;

  factory ModelFilter.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const ModelFilter();
    final type = j['type'] as String? ?? 'all';
    final models = (j['models'] as List? ?? const [])
        .map((e) => '$e'.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return ModelFilter(type: type, models: type == 'all' ? const [] : models);
  }

  Map<String, dynamic> toJson() =>
      {'type': type, 'models': type == 'all' ? <String>[] : models};
}

@immutable
class ContentModerationApiKeyStatus {
  const ContentModerationApiKeyStatus({
    required this.index,
    required this.keyHash,
    required this.masked,
    required this.status,
    required this.failureCount,
    required this.successCount,
    required this.lastError,
    required this.lastLatencyMs,
    required this.lastHttpStatus,
    required this.configured,
    this.lastCheckedAt,
    this.frozenUntil,
  });

  final int index;
  final String keyHash;
  final String masked;
  final String status; // unknown / ok / error / frozen
  final int failureCount;
  final int successCount;
  final String lastError;
  final int lastLatencyMs;
  final int lastHttpStatus;
  final bool configured;
  final String? lastCheckedAt;
  final String? frozenUntil;

  factory ContentModerationApiKeyStatus.fromJson(Map<String, dynamic> j) =>
      ContentModerationApiKeyStatus(
        index: (j['index'] as num?)?.toInt() ?? 0,
        keyHash: j['key_hash'] as String? ?? '',
        masked: j['masked'] as String? ?? '',
        status: j['status'] as String? ?? 'unknown',
        failureCount: (j['failure_count'] as num?)?.toInt() ?? 0,
        successCount: (j['success_count'] as num?)?.toInt() ?? 0,
        lastError: j['last_error'] as String? ?? '',
        lastLatencyMs: (j['last_latency_ms'] as num?)?.toInt() ?? 0,
        lastHttpStatus: (j['last_http_status'] as num?)?.toInt() ?? 0,
        configured: j['configured'] as bool? ?? false,
        lastCheckedAt: j['last_checked_at'] as String?,
        frozenUntil: j['frozen_until'] as String?,
      );
}

@immutable
class ContentModerationApiKeyLoad {
  const ContentModerationApiKeyLoad({
    required this.masked,
    required this.status,
    required this.active,
    required this.total,
    required this.avgLatencyMs,
    required this.lastLatencyMs,
  });

  final String masked;
  final String status;
  final int active;
  final int total;
  final num avgLatencyMs;
  final int lastLatencyMs;

  factory ContentModerationApiKeyLoad.fromJson(Map<String, dynamic> j) =>
      ContentModerationApiKeyLoad(
        masked: j['masked'] as String? ?? '',
        status: j['status'] as String? ?? 'unknown',
        active: (j['active'] as num?)?.toInt() ?? 0,
        total: (j['total'] as num?)?.toInt() ?? 0,
        avgLatencyMs: j['avg_latency_ms'] as num? ?? 0,
        lastLatencyMs: (j['last_latency_ms'] as num?)?.toInt() ?? 0,
      );
}

/// 内容审核配置(对照 web ContentModerationConfig)。
@immutable
class ContentModerationConfig {
  const ContentModerationConfig({
    required this.enabled,
    required this.mode,
    required this.baseUrl,
    required this.model,
    required this.apiKeyConfigured,
    required this.apiKeyCount,
    required this.apiKeyMasks,
    required this.apiKeyStatuses,
    required this.timeoutMs,
    required this.sampleRate,
    required this.allGroups,
    required this.groupIds,
    required this.recordNonHits,
    required this.thresholds,
    required this.workerCount,
    required this.queueSize,
    required this.blockStatus,
    required this.blockMessage,
    required this.emailOnHit,
    required this.autoBanEnabled,
    required this.banThreshold,
    required this.violationWindowHours,
    required this.retryCount,
    required this.hitRetentionDays,
    required this.nonHitRetentionDays,
    required this.preHashCheckEnabled,
    required this.blockedKeywords,
    required this.keywordBlockingMode,
    required this.modelFilter,
  });

  final bool enabled;
  final String mode;
  final String baseUrl;
  final String model;
  final bool apiKeyConfigured;
  final int apiKeyCount;
  final List<String> apiKeyMasks;
  final List<ContentModerationApiKeyStatus> apiKeyStatuses;
  final int timeoutMs;
  final num sampleRate;
  final bool allGroups;
  final List<int> groupIds;
  final bool recordNonHits;
  final Map<String, num> thresholds; // 0-1 分数
  final int workerCount;
  final int queueSize;
  final int blockStatus;
  final String blockMessage;
  final bool emailOnHit;
  final bool autoBanEnabled;
  final int banThreshold;
  final int violationWindowHours;
  final int retryCount;
  final int hitRetentionDays;
  final int nonHitRetentionDays;
  final bool preHashCheckEnabled;
  final List<String> blockedKeywords;
  final String keywordBlockingMode;
  final ModelFilter modelFilter;

  factory ContentModerationConfig.fromJson(Map<String, dynamic> j) =>
      ContentModerationConfig(
        enabled: j['enabled'] as bool? ?? false,
        mode: j['mode'] as String? ?? 'pre_block',
        baseUrl: j['base_url'] as String? ?? 'https://api.openai.com',
        model: j['model'] as String? ?? 'omni-moderation-latest',
        apiKeyConfigured: j['api_key_configured'] as bool? ?? false,
        apiKeyCount: (j['api_key_count'] as num?)?.toInt() ?? 0,
        apiKeyMasks: (j['api_key_masks'] as List? ?? const [])
            .map((e) => '$e')
            .toList(),
        apiKeyStatuses: (j['api_key_statuses'] as List? ?? const [])
            .whereType<Map>()
            .map((e) =>
                ContentModerationApiKeyStatus.fromJson(e.cast<String, dynamic>()))
            .toList(),
        timeoutMs: (j['timeout_ms'] as num?)?.toInt() ?? 3000,
        sampleRate: j['sample_rate'] as num? ?? 100,
        allGroups: j['all_groups'] as bool? ?? true,
        groupIds: (j['group_ids'] as List? ?? const [])
            .map((e) => (e as num).toInt())
            .toList(),
        recordNonHits: j['record_non_hits'] as bool? ?? false,
        thresholds: ((j['thresholds'] as Map?) ?? const {})
            .map((k, v) => MapEntry('$k', (v as num?) ?? 0)),
        workerCount: (j['worker_count'] as num?)?.toInt() ?? 4,
        queueSize: (j['queue_size'] as num?)?.toInt() ?? 32768,
        blockStatus: (j['block_status'] as num?)?.toInt() ?? 403,
        blockMessage: j['block_message'] as String? ?? '',
        emailOnHit: j['email_on_hit'] as bool? ?? true,
        autoBanEnabled: j['auto_ban_enabled'] as bool? ?? true,
        banThreshold: (j['ban_threshold'] as num?)?.toInt() ?? 10,
        violationWindowHours:
            (j['violation_window_hours'] as num?)?.toInt() ?? 720,
        retryCount: (j['retry_count'] as num?)?.toInt() ?? 2,
        hitRetentionDays: (j['hit_retention_days'] as num?)?.toInt() ?? 180,
        nonHitRetentionDays:
            (j['non_hit_retention_days'] as num?)?.toInt() ?? 3,
        preHashCheckEnabled: j['pre_hash_check_enabled'] as bool? ?? false,
        blockedKeywords: (j['blocked_keywords'] as List? ?? const [])
            .map((e) => '$e')
            .toList(),
        keywordBlockingMode:
            j['keyword_blocking_mode'] as String? ?? 'keyword_and_api',
        modelFilter:
            ModelFilter.fromJson((j['model_filter'] as Map?)?.cast<String, dynamic>()),
      );
}

/// 运行时状态(对照 web ContentModerationRuntimeStatus,取展示需要的字段)。
@immutable
class ContentModerationStatus {
  const ContentModerationStatus({
    required this.enabled,
    required this.mode,
    required this.workerCount,
    required this.maxWorkers,
    required this.activeWorkers,
    required this.idleWorkers,
    required this.queueSize,
    required this.queueLength,
    required this.queueUsagePercent,
    required this.enqueued,
    required this.dropped,
    required this.processed,
    required this.errors,
    required this.preBlockChecked,
    required this.preBlockAllowed,
    required this.preBlockBlocked,
    required this.preBlockErrors,
    required this.preBlockAvgLatencyMs,
    required this.apiKeyLoads,
    required this.apiKeyStatuses,
    required this.flaggedHashCount,
    required this.lastCleanupDeletedHit,
    required this.lastCleanupDeletedNonHit,
    this.lastCleanupAt,
  });

  final bool enabled;
  final String mode;
  final int workerCount;
  final int maxWorkers;
  final int activeWorkers;
  final int idleWorkers;
  final int queueSize;
  final int queueLength;
  final num queueUsagePercent;
  final int enqueued;
  final int dropped;
  final int processed;
  final int errors;
  final int preBlockChecked;
  final int preBlockAllowed;
  final int preBlockBlocked;
  final int preBlockErrors;
  final num preBlockAvgLatencyMs;
  final List<ContentModerationApiKeyLoad> apiKeyLoads;
  final List<ContentModerationApiKeyStatus> apiKeyStatuses;
  final int flaggedHashCount;
  final int lastCleanupDeletedHit;
  final int lastCleanupDeletedNonHit;
  final String? lastCleanupAt;

  factory ContentModerationStatus.fromJson(Map<String, dynamic> j) =>
      ContentModerationStatus(
        enabled: j['enabled'] as bool? ?? false,
        mode: j['mode'] as String? ?? 'off',
        workerCount: (j['worker_count'] as num?)?.toInt() ?? 0,
        maxWorkers: (j['max_workers'] as num?)?.toInt() ?? 0,
        activeWorkers: (j['active_workers'] as num?)?.toInt() ?? 0,
        idleWorkers: (j['idle_workers'] as num?)?.toInt() ?? 0,
        queueSize: (j['queue_size'] as num?)?.toInt() ?? 0,
        queueLength: (j['queue_length'] as num?)?.toInt() ?? 0,
        queueUsagePercent: j['queue_usage_percent'] as num? ?? 0,
        enqueued: (j['enqueued'] as num?)?.toInt() ?? 0,
        dropped: (j['dropped'] as num?)?.toInt() ?? 0,
        processed: (j['processed'] as num?)?.toInt() ?? 0,
        errors: (j['errors'] as num?)?.toInt() ?? 0,
        preBlockChecked: (j['pre_block_checked'] as num?)?.toInt() ?? 0,
        preBlockAllowed: (j['pre_block_allowed'] as num?)?.toInt() ?? 0,
        preBlockBlocked: (j['pre_block_blocked'] as num?)?.toInt() ?? 0,
        preBlockErrors: (j['pre_block_errors'] as num?)?.toInt() ?? 0,
        preBlockAvgLatencyMs: j['pre_block_avg_latency_ms'] as num? ?? 0,
        apiKeyLoads: (j['pre_block_api_key_loads'] as List? ?? const [])
            .whereType<Map>()
            .map((e) =>
                ContentModerationApiKeyLoad.fromJson(e.cast<String, dynamic>()))
            .toList(),
        apiKeyStatuses: (j['api_key_statuses'] as List? ?? const [])
            .whereType<Map>()
            .map((e) =>
                ContentModerationApiKeyStatus.fromJson(e.cast<String, dynamic>()))
            .toList(),
        flaggedHashCount: (j['flagged_hash_count'] as num?)?.toInt() ?? 0,
        lastCleanupDeletedHit:
            (j['last_cleanup_deleted_hit'] as num?)?.toInt() ?? 0,
        lastCleanupDeletedNonHit:
            (j['last_cleanup_deleted_non_hit'] as num?)?.toInt() ?? 0,
        lastCleanupAt: j['last_cleanup_at'] as String?,
      );
}

@immutable
class ModerationTestAuditResult {
  const ModerationTestAuditResult({
    required this.flagged,
    required this.highestCategory,
    required this.highestScore,
    required this.compositeScore,
    required this.categoryScores,
    required this.thresholds,
  });

  final bool flagged;
  final String highestCategory;
  final num highestScore;
  final num compositeScore;
  final Map<String, num> categoryScores;
  final Map<String, num> thresholds;

  factory ModerationTestAuditResult.fromJson(Map<String, dynamic> j) =>
      ModerationTestAuditResult(
        flagged: j['flagged'] as bool? ?? false,
        highestCategory: j['highest_category'] as String? ?? '',
        highestScore: j['highest_score'] as num? ?? 0,
        compositeScore: j['composite_score'] as num? ?? 0,
        categoryScores: ((j['category_scores'] as Map?) ?? const {})
            .map((k, v) => MapEntry('$k', (v as num?) ?? 0)),
        thresholds: ((j['thresholds'] as Map?) ?? const {})
            .map((k, v) => MapEntry('$k', (v as num?) ?? 0)),
      );
}

@immutable
class TestApiKeysResult {
  const TestApiKeysResult({required this.items, this.auditResult});
  final List<ContentModerationApiKeyStatus> items;
  final ModerationTestAuditResult? auditResult;

  factory TestApiKeysResult.fromJson(Map<String, dynamic> j) =>
      TestApiKeysResult(
        items: (j['items'] as List? ?? const [])
            .whereType<Map>()
            .map((e) =>
                ContentModerationApiKeyStatus.fromJson(e.cast<String, dynamic>()))
            .toList(),
        auditResult: j['audit_result'] is Map
            ? ModerationTestAuditResult.fromJson(
                (j['audit_result'] as Map).cast<String, dynamic>())
            : null,
      );
}

/// 内容审核日志(对照 web ContentModerationLog)。
@immutable
class ModerationLog {
  const ModerationLog({
    required this.id,
    required this.requestId,
    required this.userId,
    required this.userEmail,
    required this.apiKeyName,
    required this.groupName,
    required this.endpoint,
    required this.provider,
    required this.model,
    required this.mode,
    required this.action,
    required this.flagged,
    required this.highestCategory,
    required this.highestScore,
    required this.categoryScores,
    required this.thresholdSnapshot,
    required this.inputExcerpt,
    required this.error,
    required this.violationCount,
    required this.autoBanned,
    required this.emailSent,
    required this.userStatus,
    required this.createdAt,
    this.upstreamLatencyMs,
  });

  final int id;
  final String requestId;
  final int? userId;
  final String userEmail;
  final String apiKeyName;
  final String groupName;
  final String endpoint;
  final String provider;
  final String model;
  final String mode;
  final String action;
  final bool flagged;
  final String highestCategory;
  final num highestScore;
  final Map<String, num> categoryScores;
  final Map<String, num> thresholdSnapshot;
  final String inputExcerpt;
  final String error;
  final int violationCount;
  final bool autoBanned;
  final bool emailSent;
  final String userStatus;
  final String createdAt;
  final int? upstreamLatencyMs;

  bool get canUnban => autoBanned && (userId ?? 0) > 0 && userStatus == 'disabled';

  /// 解封后就地更新用户状态(用于日志行刷新)。
  ModerationLog copyWithUserStatus(String status) => ModerationLog(
        id: id,
        requestId: requestId,
        userId: userId,
        userEmail: userEmail,
        apiKeyName: apiKeyName,
        groupName: groupName,
        endpoint: endpoint,
        provider: provider,
        model: model,
        mode: mode,
        action: action,
        flagged: flagged,
        highestCategory: highestCategory,
        highestScore: highestScore,
        categoryScores: categoryScores,
        thresholdSnapshot: thresholdSnapshot,
        inputExcerpt: inputExcerpt,
        error: error,
        violationCount: violationCount,
        autoBanned: autoBanned,
        emailSent: emailSent,
        userStatus: status,
        createdAt: createdAt,
        upstreamLatencyMs: upstreamLatencyMs,
      );


  factory ModerationLog.fromJson(Map<String, dynamic> j) => ModerationLog(
        id: (j['id'] as num?)?.toInt() ?? 0,
        requestId: j['request_id'] as String? ?? '',
        userId: (j['user_id'] as num?)?.toInt(),
        userEmail: j['user_email'] as String? ?? '',
        apiKeyName: j['api_key_name'] as String? ?? '',
        groupName: j['group_name'] as String? ?? '',
        endpoint: j['endpoint'] as String? ?? '',
        provider: j['provider'] as String? ?? '',
        model: j['model'] as String? ?? '',
        mode: j['mode'] as String? ?? '',
        action: j['action'] as String? ?? '',
        flagged: j['flagged'] as bool? ?? false,
        highestCategory: j['highest_category'] as String? ?? '',
        highestScore: j['highest_score'] as num? ?? 0,
        categoryScores: ((j['category_scores'] as Map?) ?? const {})
            .map((k, v) => MapEntry('$k', (v as num?) ?? 0)),
        thresholdSnapshot: ((j['threshold_snapshot'] as Map?) ?? const {})
            .map((k, v) => MapEntry('$k', (v as num?) ?? 0)),
        inputExcerpt: j['input_excerpt'] as String? ?? '',
        error: j['error'] as String? ?? '',
        violationCount: (j['violation_count'] as num?)?.toInt() ?? 0,
        autoBanned: j['auto_banned'] as bool? ?? false,
        emailSent: j['email_sent'] as bool? ?? false,
        userStatus: j['user_status'] as String? ?? '',
        createdAt: j['created_at'] as String? ?? '',
        upstreamLatencyMs: (j['upstream_latency_ms'] as num?)?.toInt(),
      );
}

@immutable
class ModerationLogsPage {
  const ModerationLogsPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pages,
  });

  final List<ModerationLog> items;
  final int total;
  final int page;
  final int pages;

  factory ModerationLogsPage.fromJson(Map<String, dynamic> json) {
    final list = json['items'] as List? ?? const [];
    return ModerationLogsPage(
      items: list
          .whereType<Map>()
          .map((e) => ModerationLog.fromJson(e.cast<String, dynamic>()))
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pages: (json['pages'] as num?)?.toInt() ?? 1,
    );
  }
}

/// 管理端风控(内容审核)API(对照 web api/admin/riskControl.ts)。
class AdminRiskControlApi {
  AdminRiskControlApi(this._client);

  final ApiClient _client;

  Future<ContentModerationConfig> getConfig() async {
    final data = await _client.get<dynamic>('/admin/risk-control/config');
    return ContentModerationConfig.fromJson(
        (data as Map).cast<String, dynamic>());
  }

  Future<ContentModerationConfig> updateConfig(
      Map<String, dynamic> payload) async {
    final data =
        await _client.put<dynamic>('/admin/risk-control/config', data: payload);
    return ContentModerationConfig.fromJson(
        (data as Map).cast<String, dynamic>());
  }

  Future<ContentModerationStatus> getStatus() async {
    final data = await _client.get<dynamic>('/admin/risk-control/status');
    return ContentModerationStatus.fromJson(
        (data as Map).cast<String, dynamic>());
  }

  Future<TestApiKeysResult> testApiKeys({
    List<String>? apiKeys,
    String? baseUrl,
    String? model,
    int? timeoutMs,
    String? prompt,
  }) async {
    final data =
        await _client.post<dynamic>('/admin/risk-control/api-keys/test', data: {
      if (apiKeys != null && apiKeys.isNotEmpty) 'api_keys': apiKeys,
      if (baseUrl != null && baseUrl.isNotEmpty) 'base_url': baseUrl,
      if (model != null && model.isNotEmpty) 'model': model,
      'timeout_ms': ?timeoutMs,
      if (prompt != null && prompt.isNotEmpty) 'prompt': prompt,
    });
    return TestApiKeysResult.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<ModerationLogsPage> listLogs({
    int page = 1,
    int pageSize = 20,
    String? result,
    int? groupId,
    String? endpoint,
    String? search,
    String? from,
    String? to,
  }) async {
    final data = await _client.get<dynamic>('/admin/risk-control/logs', query: {
      'page': page,
      'page_size': pageSize,
      if (result != null && result.isNotEmpty) 'result': result,
      if (groupId != null && groupId > 0) 'group_id': groupId,
      if (endpoint != null && endpoint.isNotEmpty) 'endpoint': endpoint,
      if (search != null && search.isNotEmpty) 'search': search,
      if (from != null && from.isNotEmpty) 'from': from,
      if (to != null && to.isNotEmpty) 'to': to,
    });
    return ModerationLogsPage.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<String> unbanUser(int userId) async {
    final data = await _client
        .post<dynamic>('/admin/risk-control/users/$userId/unban');
    return (data as Map?)?['status'] as String? ?? 'active';
  }

  Future<void> deleteFlaggedHash(String inputHash) => _client.delete<dynamic>(
      '/admin/risk-control/hashes',
      data: {'input_hash': inputHash});

  Future<int> clearFlaggedHashes() async {
    final data = await _client.delete<dynamic>('/admin/risk-control/hashes/all');
    return (data as Map?)?['deleted'] as int? ?? 0;
  }
}
