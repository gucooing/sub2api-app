import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';

/// 代理服务器(HTTP/SOCKS)。对照 web Proxy。
@immutable
class Proxy {
  const Proxy({
    required this.id,
    required this.name,
    required this.protocol,
    required this.host,
    required this.port,
    this.username,
    this.status = 'active',
    this.accountCount,
    this.latencyMs,
    this.latencyStatus,
    this.ipAddress,
    this.country,
    this.countryCode,
    this.region,
    this.city,
    this.qualityStatus,
    this.qualityScore,
    this.qualityGrade,
    this.qualitySummary,
    this.expiresAt,
    this.fallbackMode = 'none',
    this.backupProxyId,
    this.expiryWarnDays,
  });

  final int id;
  final String name;
  final String protocol; // http / https / socks5 / socks5h
  final String host;
  final int port;
  final String? username;
  final String status; // active / inactive / expired
  final int? accountCount;
  final num? latencyMs;
  final String? latencyStatus; // success / failed
  final String? ipAddress;
  final String? country;
  final String? countryCode;
  final String? region;
  final String? city;
  final String? qualityStatus; // healthy / warn / challenge / failed
  final num? qualityScore;
  final String? qualityGrade;
  final String? qualitySummary;
  final String? expiresAt;
  final String fallbackMode; // none / proxy / direct
  final int? backupProxyId;
  final int? expiryWarnDays;

  String get endpoint => '$protocol://$host:$port';

  String get location => [city, region, country]
      .where((e) => e != null && e.isNotEmpty)
      .join(', ');

  factory Proxy.fromJson(Map<String, dynamic> j) => Proxy(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: j['name'] as String? ?? '',
        protocol: j['protocol'] as String? ?? 'http',
        host: j['host'] as String? ?? '',
        port: (j['port'] as num?)?.toInt() ?? 0,
        username: j['username'] as String?,
        status: j['status'] as String? ?? 'active',
        accountCount: (j['account_count'] as num?)?.toInt(),
        latencyMs: j['latency_ms'] as num?,
        latencyStatus: j['latency_status'] as String?,
        ipAddress: j['ip_address'] as String?,
        country: j['country'] as String?,
        countryCode: j['country_code'] as String?,
        region: j['region'] as String?,
        city: j['city'] as String?,
        qualityStatus: j['quality_status'] as String?,
        qualityScore: j['quality_score'] as num?,
        qualityGrade: j['quality_grade'] as String?,
        qualitySummary: j['quality_summary'] as String?,
        expiresAt: j['expires_at'] as String?,
        fallbackMode: j['fallback_mode'] as String? ?? 'none',
        backupProxyId: (j['backup_proxy_id'] as num?)?.toInt(),
        expiryWarnDays: (j['expiry_warn_days'] as num?)?.toInt(),
      );
}

@immutable
class ProxyPage {
  const ProxyPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pages,
  });

  final List<Proxy> items;
  final int total;
  final int page;
  final int pages;

  factory ProxyPage.fromJson(Map<String, dynamic> json) {
    final list = json['items'] as List? ?? const [];
    return ProxyPage(
      items: list
          .whereType<Map>()
          .map((e) => Proxy.fromJson(e.cast<String, dynamic>()))
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pages: (json['pages'] as num?)?.toInt() ?? 1,
    );
  }
}

/// 代理连通性测试结果。
@immutable
class ProxyTestResult {
  const ProxyTestResult({
    required this.success,
    required this.message,
    this.latencyMs,
    this.ipAddress,
    this.city,
    this.region,
    this.country,
  });

  final bool success;
  final String message;
  final num? latencyMs;
  final String? ipAddress;
  final String? city;
  final String? region;
  final String? country;

  factory ProxyTestResult.fromJson(Map<String, dynamic> j) => ProxyTestResult(
        success: j['success'] as bool? ?? false,
        message: j['message'] as String? ?? '',
        latencyMs: j['latency_ms'] as num?,
        ipAddress: j['ip_address'] as String?,
        city: j['city'] as String?,
        region: j['region'] as String?,
        country: j['country'] as String?,
      );
}

/// 代理质量检测单项。
@immutable
class ProxyQualityItem {
  const ProxyQualityItem({
    required this.target,
    required this.status,
    this.httpStatus,
    this.latencyMs,
    this.message,
  });

  final String target;
  final String status; // pass / warn / fail / challenge
  final int? httpStatus;
  final num? latencyMs;
  final String? message;

  factory ProxyQualityItem.fromJson(Map<String, dynamic> j) => ProxyQualityItem(
        target: j['target'] as String? ?? '',
        status: j['status'] as String? ?? 'fail',
        httpStatus: (j['http_status'] as num?)?.toInt(),
        latencyMs: j['latency_ms'] as num?,
        message: j['message'] as String?,
      );
}

@immutable
class ProxyQualityResult {
  const ProxyQualityResult({
    this.score = 0,
    this.grade = '',
    this.summary = '',
    this.exitIp,
    this.country,
    this.baseLatencyMs,
    this.passedCount = 0,
    this.warnCount = 0,
    this.failedCount = 0,
    this.challengeCount = 0,
    this.items = const [],
  });

  final num score;
  final String grade;
  final String summary;
  final String? exitIp;
  final String? country;
  final num? baseLatencyMs;
  final int passedCount;
  final int warnCount;
  final int failedCount;
  final int challengeCount;
  final List<ProxyQualityItem> items;

  factory ProxyQualityResult.fromJson(Map<String, dynamic> j) =>
      ProxyQualityResult(
        score: j['score'] as num? ?? 0,
        grade: j['grade'] as String? ?? '',
        summary: j['summary'] as String? ?? '',
        exitIp: j['exit_ip'] as String?,
        country: j['country'] as String?,
        baseLatencyMs: j['base_latency_ms'] as num?,
        passedCount: (j['passed_count'] as num?)?.toInt() ?? 0,
        warnCount: (j['warn_count'] as num?)?.toInt() ?? 0,
        failedCount: (j['failed_count'] as num?)?.toInt() ?? 0,
        challengeCount: (j['challenge_count'] as num?)?.toInt() ?? 0,
        items: [
          for (final e in (j['items'] as List? ?? const []))
            if (e is Map) ProxyQualityItem.fromJson(e.cast<String, dynamic>()),
        ],
      );
}

/// 管理端代理 API(对照 web api/admin/proxies.ts)。
class AdminProxiesApi {
  AdminProxiesApi(this._client);

  final ApiClient _client;

  Future<ProxyPage> list({
    int page = 1,
    int pageSize = 20,
    String? protocol,
    String? status,
    String? search,
    String sortBy = 'created_at',
    String sortOrder = 'desc',
  }) async {
    final data = await _client.get<dynamic>('/admin/proxies', query: {
      'page': page,
      'page_size': pageSize,
      if (protocol != null && protocol.isNotEmpty) 'protocol': protocol,
      if (status != null && status.isNotEmpty) 'status': status,
      if (search != null && search.isNotEmpty) 'search': search,
      'sort_by': sortBy,
      'sort_order': sortOrder,
    });
    return ProxyPage.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 全部代理(供「备用代理」下拉选择)。
  Future<List<Proxy>> getAll() async {
    final data = await _client.get<dynamic>('/admin/proxies/all');
    final list = (data as List?) ?? const [];
    return [
      for (final e in list)
        if (e is Map) Proxy.fromJson(e.cast<String, dynamic>()),
    ];
  }

  Future<Proxy> create(Map<String, dynamic> body) async {
    final data = await _client.post<dynamic>('/admin/proxies', data: body);
    return Proxy.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<Proxy> update(int id, Map<String, dynamic> body) async {
    final data = await _client.put<dynamic>('/admin/proxies/$id', data: body);
    return Proxy.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<void> setStatus(int id, bool active) =>
      update(id, {'status': active ? 'active' : 'inactive'});

  Future<void> delete(int id) => _client.delete<dynamic>('/admin/proxies/$id');

  Future<ProxyTestResult> test(int id) async {
    final data = await _client.post<dynamic>('/admin/proxies/$id/test');
    return ProxyTestResult.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<ProxyQualityResult> qualityCheck(int id) async {
    final data =
        await _client.post<dynamic>('/admin/proxies/$id/quality-check');
    return ProxyQualityResult.fromJson((data as Map).cast<String, dynamic>());
  }
}
