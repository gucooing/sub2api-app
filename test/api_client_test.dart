import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sub2api/src/core/network/api_client.dart';
import 'package:sub2api/src/core/network/api_exception.dart';

/// 以 (method path) 为键返回预设响应的假适配器;支持按调用次数变化的脚本化响应。
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.routes);

  /// 'GET /ping' → 依次出队的响应列表(最后一个会被重复使用)。
  final Map<String, List<ResponseBody>> routes;
  final List<RequestOptions> requests = [];

  static ResponseBody json(int status, Object body) => ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final key = '${options.method} ${options.path}';
    final queue = routes[key];
    if (queue == null || queue.isEmpty) {
      return ResponseBody.fromString('not found', 404);
    }
    return queue.length > 1 ? queue.removeAt(0) : queue.first;
  }

  @override
  void close({bool force = false}) {}
}

class FakeTokens implements TokenProvider {
  FakeTokens({this.access, this.refresh});

  String? access;
  String? refresh;
  int refreshedCount = 0;
  int expiredCount = 0;

  @override
  Future<String?> get accessToken async => access;

  @override
  Future<String?> get refreshToken async => refresh;

  @override
  Future<void> onTokensRefreshed(String accessToken, String? refreshToken) async {
    refreshedCount++;
    access = accessToken;
    if (refreshToken != null) refresh = refreshToken;
  }

  @override
  Future<void> onSessionExpired() async {
    expiredCount++;
  }
}

ApiClient buildClient(FakeAdapter adapter, FakeTokens tokens) {
  final dio = Dio()..httpClientAdapter = adapter;
  return ApiClient(
    origin: 'https://example.com/',
    tokens: tokens,
    localeTag: () => 'zh-CN',
    dio: dio,
    // 刷新走同一个假适配器
    refreshDioFactory: (options) => Dio(options)..httpClientAdapter = adapter,
  );
}

void main() {
  test('baseUrl 规范化并解封 {code,message,data}', () async {
    final adapter = FakeAdapter({
      'GET /ping': [
        FakeAdapter.json(200, {'code': 0, 'message': 'ok', 'data': {'x': 1}}),
      ],
    });
    final client = buildClient(adapter, FakeTokens(access: 't1'));

    final data = await client.get<Map<String, dynamic>>('/ping');

    expect(data, {'x': 1});
    final req = adapter.requests.single;
    expect(req.baseUrl, 'https://example.com/api/v1');
    expect(req.headers['Authorization'], 'Bearer t1');
    expect(req.headers['Accept-Language'], 'zh-CN');
    expect(req.queryParameters.containsKey('timezone'), isTrue);
  });

  test('封套 code 非 0 抛业务 ApiException', () async {
    final adapter = FakeAdapter({
      'GET /boom': [
        FakeAdapter.json(200, {'code': 1001, 'message': '余额不足', 'data': null}),
      ],
    });
    final client = buildClient(adapter, FakeTokens());

    expect(
      () => client.get<dynamic>('/boom'),
      throwsA(isA<ApiException>()
          .having((e) => e.kind, 'kind', ApiExceptionKind.business)
          .having((e) => e.serverMessage, 'msg', '余额不足')
          .having((e) => e.businessCode, 'code', 1001)),
    );
  });

  test('HTTP 错误归一化并带 statusCode 与服务端文案', () async {
    final adapter = FakeAdapter({
      'GET /500': [
        FakeAdapter.json(500, {'detail': 'boom'}),
      ],
    });
    final client = buildClient(adapter, FakeTokens());

    expect(
      () => client.get<dynamic>('/500'),
      throwsA(isA<ApiException>()
          .having((e) => e.kind, 'kind', ApiExceptionKind.http)
          .having((e) => e.statusCode, 'status', 500)
          .having((e) => e.serverMessage, 'msg', 'boom')),
    );
  });

  test('401 → 刷新令牌 → 重放成功', () async {
    final adapter = FakeAdapter({
      'GET /me': [
        FakeAdapter.json(401, {'code': 401, 'message': 'token expired'}),
        FakeAdapter.json(200, {'code': 0, 'message': 'ok', 'data': {'id': 7}}),
      ],
      'POST /auth/refresh': [
        FakeAdapter.json(200, {
          'code': 0,
          'message': 'ok',
          'data': {
            'access_token': 'new-access',
            'refresh_token': 'new-refresh',
            'expires_in': 3600,
          },
        }),
      ],
    });
    final tokens = FakeTokens(access: 'old', refresh: 'r1');
    final client = buildClient(adapter, tokens);

    final data = await client.get<Map<String, dynamic>>('/me');

    expect(data, {'id': 7});
    expect(tokens.refreshedCount, 1);
    expect(tokens.access, 'new-access');
    expect(tokens.refresh, 'new-refresh');
    expect(tokens.expiredCount, 0);
    // 重放请求应带新令牌
    final retried = adapter.requests
        .where((r) => r.path == '/me')
        .last;
    expect(retried.headers['Authorization'], 'Bearer new-access');
  });

  test('401 且无 refresh_token → 会话过期回调并抛 401', () async {
    final adapter = FakeAdapter({
      'GET /me': [
        FakeAdapter.json(401, {'code': 401, 'message': 'unauthorized'}),
      ],
    });
    final tokens = FakeTokens(access: 'old', refresh: null);
    final client = buildClient(adapter, tokens);

    await expectLater(
      client.get<dynamic>('/me'),
      throwsA(isA<ApiException>()
          .having((e) => e.statusCode, 'status', 401)),
    );
    expect(tokens.expiredCount, 1);
  });

  test('timezoneParam:整小时映射 Etc 区,半小时跳过', () {
    expect(ApiClient.timezoneParam(const Duration(hours: 8)), 'Etc/GMT-8');
    expect(ApiClient.timezoneParam(const Duration(hours: -5)), 'Etc/GMT+5');
    expect(ApiClient.timezoneParam(Duration.zero), 'Etc/GMT');
    expect(
        ApiClient.timezoneParam(const Duration(hours: 5, minutes: 30)), isNull);
  });
}
