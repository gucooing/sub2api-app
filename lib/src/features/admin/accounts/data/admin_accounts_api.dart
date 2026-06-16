import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';

/// 上游账号(管理端账号池)。
///
/// 编辑/新增表单需要逐键回写 `credentials`/`extra`,因此这里保留后端返回的
/// **原始脱敏 map**(`credentials`/`extra`/`credentialsStatus`),以及从 extra
/// 提取的强类型字段,字段集合与 web `Account` 对齐(详见
/// `backend/internal/handler/dto/types.go` 的 `Account`)。
@immutable
class AdminAccount {
  const AdminAccount({
    required this.id,
    required this.name,
    required this.platform,
    required this.type,
    required this.status,
    this.notes,
    this.errorMessage,
    this.concurrency = 0,
    this.currentConcurrency = 0,
    this.priority = 0,
    this.rateMultiplier,
    this.schedulable = true,
    this.lastUsedAt,
    this.createdAt,
    this.updatedAt,
    this.expiresAt,
    this.autoPauseOnExpired = false,
    this.groupNames = const [],
    this.groupIds = const [],
    this.proxyId,
    this.privacyMode,
    this.rateLimitResetAt,
    this.overloadUntil,
    this.tempUnschedulableUntil,
    this.tempUnschedulableReason,
    this.quotaLimit,
    this.quotaUsed,
    this.quotaDailyLimit,
    this.quotaWeeklyLimit,
    this.quotaDailyResetMode,
    this.quotaDailyResetHour,
    this.quotaWeeklyResetMode,
    this.quotaWeeklyResetDay,
    this.quotaWeeklyResetHour,
    this.quotaResetTimezone,
    this.quotaNotifyDailyEnabled,
    this.quotaNotifyDailyThreshold,
    this.quotaNotifyWeeklyEnabled,
    this.quotaNotifyWeeklyThreshold,
    this.quotaNotifyTotalEnabled,
    this.quotaNotifyTotalThreshold,
    this.windowCostLimit,
    this.windowCostStickyReserve,
    this.maxSessions,
    this.sessionIdleTimeoutMinutes,
    this.baseRpm,
    this.rpmStrategy,
    this.rpmStickyBuffer,
    this.userMsgQueueMode,
    this.enableTlsFingerprint,
    this.tlsFingerprintProfileId,
    this.sessionIdMaskingEnabled,
    this.cacheTtlOverrideEnabled,
    this.cacheTtlOverrideTarget,
    this.customBaseUrlEnabled,
    this.customBaseUrl,
    this.loadFactor,
    this.credentials = const {},
    this.credentialsStatus = const {},
    this.extra = const {},
  });

  final int id;
  final String name;
  final String platform; // anthropic / openai / gemini / antigravity
  final String type; // oauth / setup-token / apikey / bedrock / service_account / upstream
  final String status; // active / inactive / error
  final String? notes;
  final String? errorMessage;
  final int concurrency;
  final int currentConcurrency;
  final int priority;
  final double? rateMultiplier;
  final bool schedulable;
  final String? lastUsedAt;
  final String? createdAt;
  final String? updatedAt;
  final int? expiresAt; // epoch 秒
  final bool autoPauseOnExpired;
  final List<String> groupNames;
  final List<int> groupIds;
  final int? proxyId;
  final String? privacyMode;
  final String? rateLimitResetAt;
  final String? overloadUntil;
  final String? tempUnschedulableUntil;
  final String? tempUnschedulableReason;
  final num? quotaLimit;
  final num? quotaUsed;
  final num? quotaDailyLimit;
  final num? quotaWeeklyLimit;
  final String? quotaDailyResetMode; // rolling / fixed
  final int? quotaDailyResetHour;
  final String? quotaWeeklyResetMode; // rolling / fixed
  final int? quotaWeeklyResetDay;
  final int? quotaWeeklyResetHour;
  final String? quotaResetTimezone;
  final bool? quotaNotifyDailyEnabled;
  final num? quotaNotifyDailyThreshold;
  final bool? quotaNotifyWeeklyEnabled;
  final num? quotaNotifyWeeklyThreshold;
  final bool? quotaNotifyTotalEnabled;
  final num? quotaNotifyTotalThreshold;
  final num? windowCostLimit;
  final num? windowCostStickyReserve;
  final int? maxSessions;
  final int? sessionIdleTimeoutMinutes;
  final int? baseRpm;
  final String? rpmStrategy; // tiered / sticky_exempt
  final int? rpmStickyBuffer;
  final String? userMsgQueueMode; // '' / throttle / serialize
  final bool? enableTlsFingerprint;
  final int? tlsFingerprintProfileId;
  final bool? sessionIdMaskingEnabled;
  final bool? cacheTtlOverrideEnabled;
  final String? cacheTtlOverrideTarget; // 5m / 1h
  final bool? customBaseUrlEnabled;
  final String? customBaseUrl;
  final double? loadFactor;

  /// 后端返回的脱敏凭据原文(敏感键已被剔除,改由 [credentialsStatus] 暴露存在性)。
  final Map<String, dynamic> credentials;
  final Map<String, bool> credentialsStatus;

  /// 账号扩展配置原文(配额/限速/各平台开关均落在此)。
  final Map<String, dynamic> extra;

  bool get isActive => status == 'active';
  bool get isError => status == 'error';
  bool get isOauthLike => type == 'oauth' || type == 'setup-token';

  static bool _future(String? iso) {
    if (iso == null || iso.isEmpty) return false;
    final t = DateTime.tryParse(iso);
    return t != null && t.isAfter(DateTime.now());
  }

  bool get isRateLimited => _future(rateLimitResetAt);
  bool get isOverloaded => _future(overloadUntil);
  bool get isTempUnschedulable => _future(tempUnschedulableUntil);

  /// 是否有可恢复的运行态(错误/限流/过载/临时不可调度)。
  bool get hasRecoverableState =>
      isError || isRateLimited || isOverloaded || isTempUnschedulable;

  /// 配额限制(仅 apikey/bedrock 且设置了任一配额)。
  bool get hasQuotaLimit =>
      (type == 'apikey' || type == 'bedrock') &&
      ((quotaLimit ?? 0) > 0 ||
          (quotaDailyLimit ?? 0) > 0 ||
          (quotaWeeklyLimit ?? 0) > 0);

  /// 支持隐私设置(antigravity-oauth 或 openai-oauth)。
  bool get supportsPrivacy =>
      type == 'oauth' && (platform == 'antigravity' || platform == 'openai');

  factory AdminAccount.fromJson(Map<String, dynamic> json) {
    final groups = <String>[];
    final gs = json['groups'];
    if (gs is List) {
      for (final g in gs) {
        if (g is Map && g['name'] is String) groups.add(g['name'] as String);
      }
    }
    final groupIds = <int>[];
    final gids = json['group_ids'];
    if (gids is List) {
      for (final g in gids) {
        final n = (g as num?)?.toInt();
        if (n != null) groupIds.add(n);
      }
    }
    final extra = _asStringMap(json['extra']);
    final privacy = extra['privacy_mode'] as String?;
    return AdminAccount(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      platform: json['platform'] as String? ?? '',
      type: json['type'] as String? ?? '',
      status: json['status'] as String? ?? 'inactive',
      notes: json['notes'] as String?,
      errorMessage: json['error_message'] as String?,
      concurrency: (json['concurrency'] as num?)?.toInt() ?? 0,
      currentConcurrency: (json['current_concurrency'] as num?)?.toInt() ?? 0,
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      rateMultiplier: (json['rate_multiplier'] as num?)?.toDouble(),
      schedulable: json['schedulable'] as bool? ?? true,
      lastUsedAt: json['last_used_at'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      expiresAt: (json['expires_at'] as num?)?.toInt(),
      autoPauseOnExpired: json['auto_pause_on_expired'] as bool? ?? false,
      groupNames: groups,
      groupIds: groupIds,
      proxyId: (json['proxy_id'] as num?)?.toInt(),
      privacyMode: privacy,
      rateLimitResetAt: json['rate_limit_reset_at'] as String?,
      overloadUntil: json['overload_until'] as String?,
      tempUnschedulableUntil: json['temp_unschedulable_until'] as String?,
      tempUnschedulableReason: json['temp_unschedulable_reason'] as String?,
      quotaLimit: json['quota_limit'] as num?,
      quotaUsed: json['quota_used'] as num?,
      quotaDailyLimit: json['quota_daily_limit'] as num?,
      quotaWeeklyLimit: json['quota_weekly_limit'] as num?,
      quotaDailyResetMode: json['quota_daily_reset_mode'] as String?,
      quotaDailyResetHour: (json['quota_daily_reset_hour'] as num?)?.toInt(),
      quotaWeeklyResetMode: json['quota_weekly_reset_mode'] as String?,
      quotaWeeklyResetDay: (json['quota_weekly_reset_day'] as num?)?.toInt(),
      quotaWeeklyResetHour: (json['quota_weekly_reset_hour'] as num?)?.toInt(),
      quotaResetTimezone: json['quota_reset_timezone'] as String?,
      quotaNotifyDailyEnabled: json['quota_notify_daily_enabled'] as bool?,
      quotaNotifyDailyThreshold: json['quota_notify_daily_threshold'] as num?,
      quotaNotifyWeeklyEnabled: json['quota_notify_weekly_enabled'] as bool?,
      quotaNotifyWeeklyThreshold: json['quota_notify_weekly_threshold'] as num?,
      quotaNotifyTotalEnabled: json['quota_notify_total_enabled'] as bool?,
      quotaNotifyTotalThreshold: json['quota_notify_total_threshold'] as num?,
      windowCostLimit: json['window_cost_limit'] as num?,
      windowCostStickyReserve: json['window_cost_sticky_reserve'] as num?,
      maxSessions: (json['max_sessions'] as num?)?.toInt(),
      sessionIdleTimeoutMinutes:
          (json['session_idle_timeout_minutes'] as num?)?.toInt(),
      baseRpm: (json['base_rpm'] as num?)?.toInt(),
      rpmStrategy: json['rpm_strategy'] as String?,
      rpmStickyBuffer: (json['rpm_sticky_buffer'] as num?)?.toInt(),
      userMsgQueueMode: json['user_msg_queue_mode'] as String?,
      enableTlsFingerprint: json['enable_tls_fingerprint'] as bool?,
      tlsFingerprintProfileId:
          (json['tls_fingerprint_profile_id'] as num?)?.toInt(),
      sessionIdMaskingEnabled: json['session_id_masking_enabled'] as bool?,
      cacheTtlOverrideEnabled: json['cache_ttl_override_enabled'] as bool?,
      cacheTtlOverrideTarget: json['cache_ttl_override_target'] as String?,
      customBaseUrlEnabled: json['custom_base_url_enabled'] as bool?,
      customBaseUrl: json['custom_base_url'] as String?,
      loadFactor: (json['load_factor'] as num?)?.toDouble(),
      credentials: _asStringMap(json['credentials']),
      credentialsStatus: _asBoolMap(json['credentials_status']),
      extra: extra,
    );
  }

  static Map<String, dynamic> _asStringMap(dynamic v) =>
      v is Map ? v.cast<String, dynamic>() : <String, dynamic>{};

  static Map<String, bool> _asBoolMap(dynamic v) {
    if (v is! Map) return const {};
    final out = <String, bool>{};
    v.forEach((k, val) {
      if (val is bool) out['$k'] = val;
    });
    return out;
  }
}

/// 账号池分页结果。
@immutable
class AdminAccountPage {
  const AdminAccountPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pages,
  });

  final List<AdminAccount> items;
  final int total;
  final int page;
  final int pages;

  factory AdminAccountPage.fromJson(Map<String, dynamic> json) {
    final list = json['items'] as List? ?? const [];
    return AdminAccountPage(
      items: list
          .whereType<Map>()
          .map((e) => AdminAccount.fromJson(e.cast<String, dynamic>()))
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pages: (json['pages'] as num?)?.toInt() ?? 1,
    );
  }
}

/// 可测试模型(id + 展示名)。
@immutable
class TestModel {
  const TestModel({required this.id, required this.displayName});
  final String id;
  final String displayName;
}

/// 测试连接的流式事件(对照 web SSE:test_start/content/image/test_complete/error)。
@immutable
class AccountTestEvent {
  const AccountTestEvent({
    required this.type,
    this.text,
    this.model,
    this.success,
    this.error,
    this.imageUrl,
    this.mimeType,
  });

  final String type;
  final String? text;
  final String? model;
  final bool? success;
  final String? error;
  final String? imageUrl;
  final String? mimeType;

  factory AccountTestEvent.fromJson(Map<String, dynamic> j) => AccountTestEvent(
        type: j['type'] as String? ?? '',
        text: j['text'] as String?,
        model: j['model'] as String?,
        success: j['success'] as bool?,
        error: j['error'] as String?,
        imageUrl: j['image_url'] as String?,
        mimeType: j['mime_type'] as String?,
      );
}

/// 管理端账号池 API。
class AdminAccountsApi {
  AdminAccountsApi(this._client);

  final ApiClient _client;

  Future<AdminAccountPage> list({
    int page = 1,
    int pageSize = 20,
    String? platform,
    String? type,
    String? status,
    String? group,
    String? privacyMode,
    String? search,
  }) async {
    final data = await _client.get<dynamic>('/admin/accounts', query: {
      'page': page,
      'page_size': pageSize,
      if (platform != null && platform.isNotEmpty) 'platform': platform,
      if (type != null && type.isNotEmpty) 'type': type,
      if (status != null && status.isNotEmpty) 'status': status,
      if (group != null && group.isNotEmpty) 'group': group,
      if (privacyMode != null && privacyMode.isNotEmpty)
        'privacy_mode': privacyMode,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    return AdminAccountPage.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 全部分组(id+name),供筛选/编辑选择。
  Future<List<({int id, String name})>> groupsAll() async {
    final data = await _client.get<dynamic>('/admin/groups/all');
    final list = (data as List?) ?? const [];
    return [
      for (final e in list)
        if (e is Map && e['id'] != null)
          (id: (e['id'] as num).toInt(), name: '${e['name'] ?? ''}'),
    ];
  }

  /// 全部代理(id+name),供编辑选择。
  Future<List<({int id, String name})>> proxiesAll() async {
    final data = await _client.get<dynamic>('/admin/proxies/all');
    final list = (data as List?) ?? const [];
    return [
      for (final e in list)
        if (e is Map && e['id'] != null)
          (
            id: (e['id'] as num).toInt(),
            name: '${e['name'] ?? e['host'] ?? e['id']}'
          ),
    ];
  }

  Future<AdminAccount> getById(int id) async {
    final data = await _client.get<dynamic>('/admin/accounts/$id');
    return AdminAccount.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 今日统计批量(账号 id -> 今日消耗)。
  Future<Map<int, double>> batchTodayCost(List<int> ids) async {
    if (ids.isEmpty) return {};
    final data = await _client.post<dynamic>(
      '/admin/accounts/today-stats/batch',
      data: {'account_ids': ids},
    );
    final stats = ((data as Map)['stats'] as Map?) ?? {};
    final out = <int, double>{};
    stats.forEach((k, v) {
      final id = int.tryParse('$k');
      if (id != null && v is Map) {
        out[id] = (v['cost'] as num?)?.toDouble() ?? 0;
      }
    });
    return out;
  }

  Future<void> setStatus(int id, bool active) =>
      _client.put<dynamic>('/admin/accounts/$id',
          data: {'status': active ? 'active' : 'inactive'});

  Future<void> delete(int id) => _client.delete<dynamic>('/admin/accounts/$id');

  /// 创建账号(apikey/bedrock 等凭据型;OAuth 走授权流另行处理)。
  Future<AdminAccount> create(Map<String, dynamic> body) async {
    final data = await _client.post<dynamic>('/admin/accounts', data: body);
    return AdminAccount.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 编辑账号(部分字段)。
  Future<AdminAccount> update(int id, Map<String, dynamic> body) async {
    final data = await _client.put<dynamic>('/admin/accounts/$id', data: body);
    return AdminAccount.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<void> setSchedulable(int id, bool schedulable) =>
      _client.post<dynamic>('/admin/accounts/$id/schedulable',
          data: {'schedulable': schedulable});

  Future<void> recoverState(int id) =>
      _client.post<dynamic>('/admin/accounts/$id/recover-state');

  Future<void> resetQuota(int id) =>
      _client.post<dynamic>('/admin/accounts/$id/reset-quota');

  Future<void> setPrivacy(int id) =>
      _client.post<dynamic>('/admin/accounts/$id/set-privacy');

  /// 该账号可用模型(id + 展示名),测试连接选择模型用。
  Future<List<TestModel>> availableModels(int id) async {
    final data = await _client.get<dynamic>('/admin/accounts/$id/models');
    final list = (data as List?) ?? const [];
    final out = <TestModel>[];
    for (final e in list) {
      if (e is Map && e['id'] != null) {
        final mid = '${e['id']}';
        final dn = e['display_name'] as String?;
        out.add(TestModel(id: mid, displayName: dn?.isNotEmpty == true ? dn! : mid));
      } else if (e is String) {
        out.add(TestModel(id: e, displayName: e));
      }
    }
    return out;
  }

  /// 测试连接(流式):POST {model_id,prompt} → SSE,逐事件 yield,实时展示过程与结果。
  Stream<AccountTestEvent> testStream(int id,
      {required String modelId, String prompt = ''}) async* {
    final byteStream = await _client.openByteStream(
      '/admin/accounts/$id/test',
      data: {'model_id': modelId, 'prompt': prompt},
    );
    final lines = byteStream
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter());
    await for (final line in lines) {
      final t = line.trim();
      if (!t.startsWith('data:')) continue;
      final payload = t.substring(5).trim();
      if (payload.isEmpty || payload == '[DONE]') continue;
      try {
        final obj = jsonDecode(payload);
        if (obj is Map) {
          yield AccountTestEvent.fromJson(obj.cast<String, dynamic>());
        }
      } catch (_) {
        // 忽略无法解析的行。
      }
    }
  }

  Future<void> clearError(int id) =>
      _client.post<dynamic>('/admin/accounts/$id/clear-error');

  Future<void> clearRateLimit(int id) =>
      _client.post<dynamic>('/admin/accounts/$id/clear-rate-limit');

  Future<void> refreshCredentials(int id) =>
      _client.post<dynamic>('/admin/accounts/$id/refresh');

  /// 同步上游模型(antigravity 等):返回上游模型 id 列表。
  Future<List<String>> syncUpstreamModels(int id) async {
    final data = await _client
        .post<dynamic>('/admin/accounts/$id/models/sync-upstream');
    final models = (data is Map ? data['models'] : null) as List? ?? const [];
    return [for (final m in models) '$m'.trim()].where((m) => m.isNotEmpty).toList();
  }

  /// TLS 指纹配置(id+name),供高级配额(Anthropic OAuth/setup-token)选择。
  Future<List<({int id, String name})>> tlsFingerprintProfiles() async {
    final data = await _client.get<dynamic>('/admin/tls-fingerprint-profiles');
    final list = (data as List?) ?? const [];
    return [
      for (final e in list)
        if (e is Map && e['id'] != null)
          (id: (e['id'] as num).toInt(), name: '${e['name'] ?? e['id']}'),
    ];
  }
}
