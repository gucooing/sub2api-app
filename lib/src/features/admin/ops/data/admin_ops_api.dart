import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';

@immutable
class OpsPercentiles {
  const OpsPercentiles(
      {this.p50, this.p90, this.p95, this.p99, this.avg, this.max});
  final num? p50;
  final num? p90;
  final num? p95;
  final num? p99;
  final num? avg;
  final num? max;

  factory OpsPercentiles.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const OpsPercentiles();
    return OpsPercentiles(
      p50: j['p50_ms'] as num?,
      p90: j['p90_ms'] as num?,
      p95: j['p95_ms'] as num?,
      p99: j['p99_ms'] as num?,
      avg: j['avg_ms'] as num?,
      max: j['max_ms'] as num?,
    );
  }
}

/// 运维总览(对照 web OpsDashboardOverview,取展示字段)。
@immutable
class OpsOverview {
  const OpsOverview({
    required this.healthScore,
    required this.successCount,
    required this.errorCountTotal,
    required this.requestCountTotal,
    required this.tokenConsumed,
    required this.sla,
    required this.errorRate,
    required this.upstreamErrorRate,
    required this.upstream429Count,
    required this.upstream529Count,
    required this.qpsCurrent,
    required this.qpsPeak,
    required this.tpsCurrent,
    required this.tpsPeak,
    required this.duration,
    required this.ttft,
  });

  final num? healthScore;
  final int successCount;
  final int errorCountTotal;
  final int requestCountTotal;
  final num tokenConsumed;
  final num sla;
  final num errorRate;
  final num upstreamErrorRate;
  final int upstream429Count;
  final int upstream529Count;
  final num qpsCurrent;
  final num qpsPeak;
  final num tpsCurrent;
  final num tpsPeak;
  final OpsPercentiles duration;
  final OpsPercentiles ttft;

  factory OpsOverview.fromJson(Map<String, dynamic> j) {
    num n(String k) => j[k] as num? ?? 0;
    final qps = (j['qps'] as Map?)?.cast<String, dynamic>() ?? const {};
    final tps = (j['tps'] as Map?)?.cast<String, dynamic>() ?? const {};
    return OpsOverview(
      healthScore: j['health_score'] as num?,
      successCount: n('success_count').toInt(),
      errorCountTotal: n('error_count_total').toInt(),
      requestCountTotal: n('request_count_total').toInt(),
      tokenConsumed: n('token_consumed'),
      sla: n('sla'),
      errorRate: n('error_rate'),
      upstreamErrorRate: n('upstream_error_rate'),
      upstream429Count: n('upstream_429_count').toInt(),
      upstream529Count: n('upstream_529_count').toInt(),
      qpsCurrent: (qps['current'] as num?) ?? 0,
      qpsPeak: (qps['peak'] as num?) ?? 0,
      tpsCurrent: (tps['current'] as num?) ?? 0,
      tpsPeak: (tps['peak'] as num?) ?? 0,
      duration: OpsPercentiles.fromJson(
          (j['duration'] as Map?)?.cast<String, dynamic>()),
      ttft:
          OpsPercentiles.fromJson((j['ttft'] as Map?)?.cast<String, dynamic>()),
    );
  }
}

/// 错误日志(对照 web OpsErrorLog)。
@immutable
class OpsErrorLog {
  const OpsErrorLog({
    required this.id,
    required this.createdAt,
    required this.phase,
    required this.type,
    required this.errorOwner,
    required this.errorSource,
    required this.severity,
    required this.statusCode,
    required this.platform,
    required this.model,
    required this.resolved,
    required this.requestId,
    required this.message,
    required this.userEmail,
    required this.accountName,
    required this.groupName,
    this.requestPath,
    this.requestedModel,
    this.apiKeyName,
  });

  final int id;
  final String createdAt;
  final String phase;
  final String type;
  final String errorOwner;
  final String errorSource;
  final String severity;
  final int statusCode;
  final String platform;
  final String model;
  final bool resolved;
  final String requestId;
  final String message;
  final String userEmail;
  final String accountName;
  final String groupName;
  final String? requestPath;
  final String? requestedModel;
  final String? apiKeyName;

  factory OpsErrorLog.fromJson(Map<String, dynamic> j) => OpsErrorLog(
        id: (j['id'] as num?)?.toInt() ?? 0,
        createdAt: j['created_at'] as String? ?? '',
        phase: j['phase'] as String? ?? '',
        type: j['type'] as String? ?? '',
        errorOwner: j['error_owner'] as String? ?? '',
        errorSource: j['error_source'] as String? ?? '',
        severity: j['severity'] as String? ?? '',
        statusCode: (j['status_code'] as num?)?.toInt() ?? 0,
        platform: j['platform'] as String? ?? '',
        model: j['model'] as String? ?? '',
        resolved: j['resolved'] as bool? ?? false,
        requestId: j['request_id'] as String? ?? '',
        message: j['message'] as String? ?? '',
        userEmail: j['user_email'] as String? ?? '',
        accountName: j['account_name'] as String? ?? '',
        groupName: j['group_name'] as String? ?? '',
        requestPath: j['request_path'] as String?,
        requestedModel: j['requested_model'] as String?,
        apiKeyName: j['api_key_name'] as String?,
      );
}

/// 错误详情(extends 错误日志,补全 body/延迟/上游)。
@immutable
class OpsErrorDetail {
  const OpsErrorDetail({
    required this.log,
    required this.errorBody,
    required this.userAgent,
    this.clientIp,
    this.upstreamStatusCode,
    this.upstreamErrorMessage,
    this.authLatencyMs,
    this.routingLatencyMs,
    this.upstreamLatencyMs,
    this.responseLatencyMs,
    this.timeToFirstTokenMs,
  });

  final OpsErrorLog log;
  final String errorBody;
  final String userAgent;
  final String? clientIp;
  final int? upstreamStatusCode;
  final String? upstreamErrorMessage;
  final num? authLatencyMs;
  final num? routingLatencyMs;
  final num? upstreamLatencyMs;
  final num? responseLatencyMs;
  final num? timeToFirstTokenMs;

  factory OpsErrorDetail.fromJson(Map<String, dynamic> j) => OpsErrorDetail(
        log: OpsErrorLog.fromJson(j),
        errorBody: j['error_body'] as String? ?? '',
        userAgent: j['user_agent'] as String? ?? '',
        clientIp: j['client_ip'] as String?,
        upstreamStatusCode: (j['upstream_status_code'] as num?)?.toInt(),
        upstreamErrorMessage: j['upstream_error_message'] as String?,
        authLatencyMs: j['auth_latency_ms'] as num?,
        routingLatencyMs: j['routing_latency_ms'] as num?,
        upstreamLatencyMs: j['upstream_latency_ms'] as num?,
        responseLatencyMs: j['response_latency_ms'] as num?,
        timeToFirstTokenMs: j['time_to_first_token_ms'] as num?,
      );
}

/// 系统日志(对照 web OpsSystemLog)。
@immutable
class OpsSystemLog {
  const OpsSystemLog({
    required this.id,
    required this.createdAt,
    required this.level,
    required this.component,
    required this.message,
    this.requestId,
    this.platform,
    this.model,
    this.userId,
    this.accountId,
  });

  final int id;
  final String createdAt;
  final String level;
  final String component;
  final String message;
  final String? requestId;
  final String? platform;
  final String? model;
  final int? userId;
  final int? accountId;

  factory OpsSystemLog.fromJson(Map<String, dynamic> j) => OpsSystemLog(
        id: (j['id'] as num?)?.toInt() ?? 0,
        createdAt: j['created_at'] as String? ?? '',
        level: j['level'] as String? ?? '',
        component: j['component'] as String? ?? '',
        message: j['message'] as String? ?? '',
        requestId: j['request_id'] as String?,
        platform: j['platform'] as String?,
        model: j['model'] as String?,
        userId: (j['user_id'] as num?)?.toInt(),
        accountId: (j['account_id'] as num?)?.toInt(),
      );
}

/// 告警规则(对照 web AlertRule)。
@immutable
class AlertRule {
  const AlertRule({
    required this.id,
    required this.name,
    required this.enabled,
    required this.metricType,
    required this.operator,
    required this.threshold,
    required this.windowMinutes,
    required this.severity,
    required this.notifyEmail,
    this.description,
    this.lastTriggeredAt,
  });

  final int id;
  final String name;
  final bool enabled;
  final String metricType;
  final String operator;
  final num threshold;
  final int windowMinutes;
  final String severity;
  final bool notifyEmail;
  final String? description;
  final String? lastTriggeredAt;

  factory AlertRule.fromJson(Map<String, dynamic> j) => AlertRule(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: j['name'] as String? ?? '',
        enabled: j['enabled'] as bool? ?? false,
        metricType: j['metric_type'] as String? ?? '',
        operator: j['operator'] as String? ?? '',
        threshold: j['threshold'] as num? ?? 0,
        windowMinutes: (j['window_minutes'] as num?)?.toInt() ?? 0,
        severity: j['severity'] as String? ?? '',
        notifyEmail: j['notify_email'] as bool? ?? false,
        description: j['description'] as String?,
        lastTriggeredAt: j['last_triggered_at'] as String?,
      );
}

/// 告警事件(对照 web AlertEvent)。
@immutable
class AlertEvent {
  const AlertEvent({
    required this.id,
    required this.ruleId,
    required this.severity,
    required this.status,
    required this.firedAt,
    required this.emailSent,
    this.title,
    this.description,
    this.metricValue,
    this.thresholdValue,
    this.resolvedAt,
  });

  final int id;
  final int ruleId;
  final String severity;
  final String status; // firing / resolved / manual_resolved
  final String firedAt;
  final bool emailSent;
  final String? title;
  final String? description;
  final num? metricValue;
  final num? thresholdValue;
  final String? resolvedAt;

  bool get isFiring => status == 'firing';

  factory AlertEvent.fromJson(Map<String, dynamic> j) => AlertEvent(
        id: (j['id'] as num?)?.toInt() ?? 0,
        ruleId: (j['rule_id'] as num?)?.toInt() ?? 0,
        severity: j['severity'] as String? ?? '',
        status: j['status'] as String? ?? '',
        firedAt: j['fired_at'] as String? ?? '',
        emailSent: j['email_sent'] as bool? ?? false,
        title: j['title'] as String?,
        description: j['description'] as String?,
        metricValue: j['metric_value'] as num?,
        thresholdValue: j['threshold_value'] as num?,
        resolvedAt: j['resolved_at'] as String?,
      );
}

@immutable
class OpsPage<T> {
  const OpsPage(
      {required this.items,
      required this.total,
      required this.page,
      required this.pages});
  final List<T> items;
  final int total;
  final int page;
  final int pages;

  static OpsPage<T> parse<T>(
      dynamic data, T Function(Map<String, dynamic>) fromJson) {
    final json = (data as Map).cast<String, dynamic>();
    final list = json['items'] as List? ?? const [];
    return OpsPage<T>(
      items: list
          .whereType<Map>()
          .map((e) => fromJson(e.cast<String, dynamic>()))
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pages: (json['pages'] as num?)?.toInt() ?? 1,
    );
  }
}

/// 管理端运维 API(对照 web api/admin/ops.ts,实装核心运维视图)。
class AdminOpsApi {
  AdminOpsApi(this._client);

  final ApiClient _client;

  Future<OpsOverview> getOverview(
      {String timeRange = '1h', String? platform}) async {
    final data = await _client
        .get<dynamic>('/admin/ops/dashboard/overview', query: {
      'time_range': timeRange,
      if (platform != null && platform.isNotEmpty) 'platform': platform,
    });
    return OpsOverview.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<OpsPage<OpsErrorLog>> listErrorLogs({
    int page = 1,
    int pageSize = 20,
    String timeRange = '24h',
    String? platform,
    String? resolved,
    String? q,
  }) async {
    final data = await _client.get<dynamic>('/admin/ops/errors', query: {
      'page': page,
      'page_size': pageSize,
      'time_range': timeRange,
      'view': 'errors',
      if (platform != null && platform.isNotEmpty) 'platform': platform,
      if (resolved != null && resolved.isNotEmpty) 'resolved': resolved,
      if (q != null && q.isNotEmpty) 'q': q,
    });
    return OpsPage.parse(data, OpsErrorLog.fromJson);
  }

  Future<OpsErrorDetail> getErrorLogDetail(int id) async {
    final data = await _client.get<dynamic>('/admin/ops/errors/$id');
    return OpsErrorDetail.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<void> updateErrorResolved(int id, bool resolved) =>
      _client.put<dynamic>('/admin/ops/errors/$id/resolve',
          data: {'resolved': resolved});

  Future<OpsPage<OpsSystemLog>> listSystemLogs({
    int page = 1,
    int pageSize = 20,
    String timeRange = '1h',
    String? level,
    String? component,
    String? q,
  }) async {
    final data = await _client.get<dynamic>('/admin/ops/system-logs', query: {
      'page': page,
      'page_size': pageSize,
      'time_range': timeRange,
      if (level != null && level.isNotEmpty) 'level': level,
      if (component != null && component.isNotEmpty) 'component': component,
      if (q != null && q.isNotEmpty) 'q': q,
    });
    return OpsPage.parse(data, OpsSystemLog.fromJson);
  }

  Future<int> cleanupSystemLogs({String? level, String? component, String? q}) async {
    final data = await _client.post<dynamic>('/admin/ops/system-logs/cleanup',
        data: {
          if (level != null && level.isNotEmpty) 'level': level,
          if (component != null && component.isNotEmpty) 'component': component,
          if (q != null && q.isNotEmpty) 'q': q,
        });
    return (data as Map?)?['deleted'] as int? ?? 0;
  }

  Future<List<AlertRule>> listAlertRules() async {
    final data = await _client.get<dynamic>('/admin/ops/alert-rules');
    return (data as List? ?? const [])
        .whereType<Map>()
        .map((e) => AlertRule.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<void> setAlertRuleEnabled(int id, bool enabled) =>
      _client.put<dynamic>('/admin/ops/alert-rules/$id',
          data: {'enabled': enabled});

  Future<void> deleteAlertRule(int id) =>
      _client.delete<dynamic>('/admin/ops/alert-rules/$id');

  Future<List<AlertEvent>> listAlertEvents(
      {int limit = 50, String? status, String? severity}) async {
    final data = await _client.get<dynamic>('/admin/ops/alert-events', query: {
      'limit': limit,
      if (status != null && status.isNotEmpty) 'status': status,
      if (severity != null && severity.isNotEmpty) 'severity': severity,
    });
    return (data as List? ?? const [])
        .whereType<Map>()
        .map((e) => AlertEvent.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<void> resolveAlertEvent(int id) =>
      _client.put<dynamic>('/admin/ops/alert-events/$id/status',
          data: {'status': 'manual_resolved'});
}
