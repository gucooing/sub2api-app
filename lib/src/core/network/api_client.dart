import 'dart:async';

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../logging/app_logger.dart';
import 'api_exception.dart';

/// 取当前应转发给后端的语言标签(Accept-Language)。
typedef LocaleTagProvider = String? Function();

/// 令牌读写抽象,由会话层(core/session)基于 SecureStore 实现;
/// 这里只依赖接口,便于测试与解耦。
abstract class TokenProvider {
  Future<String?> get accessToken;
  Future<String?> get refreshToken;

  /// 刷新成功后回写新令牌。
  Future<void> onTokensRefreshed(String accessToken, String? refreshToken);

  /// 刷新失败/令牌失效,会话需要登出。
  Future<void> onSessionExpired();
}

/// Sub2API 的 REST 客户端。
///
/// 能力(对齐 Web 前端 frontend/src/api/client.ts 的行为):
/// - baseUrl = `<服务器origin>/api/v1`;
/// - 请求注入 `Authorization: Bearer`、`Accept-Language`;GET 附 `timezone`;
/// - 响应解封 `{code,message,data}`:code==0 取 data,否则抛业务 [ApiException];
/// - 401 时用 refresh_token 调 `POST /auth/refresh` 单飞刷新并重放一次
///   (auth 端点本身除外),刷新失败通知会话过期。
class ApiClient {
  ApiClient({
    required String origin,
    required this._tokens,
    this._localeTag,
    Dio? dio,
    Dio Function(BaseOptions options)? refreshDioFactory,
  })  : _refreshDioFactory = refreshDioFactory ?? Dio.new,
        _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = '${_normalizeOrigin(origin)}/api/v1'
      ..connectTimeout = AppConfig.connectTimeout
      ..receiveTimeout = AppConfig.receiveTimeout
      ..headers = {'Content-Type': 'application/json'};
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: _onRequest,
      onResponse: _onResponse,
      onError: _onError,
    ));
  }

  final Dio _dio;
  final TokenProvider _tokens;
  final LocaleTagProvider? _localeTag;
  final Dio Function(BaseOptions options) _refreshDioFactory;

  /// 单飞刷新:并发 401 共享同一个刷新 Future。
  Future<String?>? _refreshing;

  static String _normalizeOrigin(String origin) {
    var o = origin.trim();
    while (o.endsWith('/')) {
      o = o.substring(0, o.length - 1);
    }
    return o;
  }

  /// 整小时时区偏移映射为 IANA Etc 区(注意 Etc 命名符号相反:UTC+8 → Etc/GMT-8);
  /// 非整小时(如 +5:30)无对应 Etc 区,返回 null 不传。
  static String? timezoneParam([Duration? offset]) {
    final d = offset ?? DateTime.now().timeZoneOffset;
    if (d.inMinutes % 60 != 0) return null;
    final h = d.inHours;
    if (h == 0) return 'Etc/GMT';
    return h > 0 ? 'Etc/GMT-$h' : 'Etc/GMT+${-h}';
  }

  Future<void> _onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _tokens.accessToken;
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    final locale = _localeTag?.call();
    if (locale != null && locale.isNotEmpty) {
      options.headers['Accept-Language'] = locale;
    }
    if (options.method.toUpperCase() == 'GET' &&
        !options.queryParameters.containsKey('timezone')) {
      final tz = timezoneParam();
      if (tz != null) options.queryParameters['timezone'] = tz;
    }
    handler.next(options);
  }

  void _onResponse(Response response, ResponseInterceptorHandler handler) {
    final body = response.data;
    if (body is Map && body.containsKey('code')) {
      final code = body['code'];
      if (code == 0) {
        response.data = body['data'];
        handler.next(response);
      } else {
        handler.reject(
          DioException(
            requestOptions: response.requestOptions,
            response: response,
            type: DioExceptionType.unknown,
            error: ApiException(
              kind: ApiExceptionKind.business,
              businessCode: code,
              serverMessage:
                  (body['message'] as String?)?.isNotEmpty == true
                      ? body['message'] as String
                      : null,
            ),
          ),
          true,
        );
      }
      return;
    }
    handler.next(response);
  }

  static bool _isAuthPath(String path) =>
      path.contains('/auth/login') ||
      path.contains('/auth/register') ||
      path.contains('/auth/refresh');

  Future<void> _onError(
      DioException err, ErrorInterceptorHandler handler) async {
    // 业务错误已包装好,直接透传。
    if (err.error is ApiException) {
      handler.next(err);
      return;
    }

    final status = err.response?.statusCode;
    final retried = err.requestOptions.extra['_retried'] == true;
    if (status == 401 && !retried && !_isAuthPath(err.requestOptions.path)) {
      final newToken = await _refreshTokenSingleFlight();
      if (newToken != null) {
        try {
          final opts = err.requestOptions;
          opts.extra['_retried'] = true;
          opts.headers['Authorization'] = 'Bearer $newToken';
          final response = await _dio.fetch(opts);
          handler.resolve(response);
          return;
        } on DioException catch (e) {
          handler.next(e);
          return;
        }
      }
      await _tokens.onSessionExpired();
    }
    handler.next(err);
  }

  Future<String?> _refreshTokenSingleFlight() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<String?> _doRefresh() async {
    final refresh = await _tokens.refreshToken;
    if (refresh == null || refresh.isEmpty) return null;
    try {
      // 独立 Dio,避免经过本客户端的拦截器造成递归。
      final raw = _refreshDioFactory(BaseOptions(
        baseUrl: _dio.options.baseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
      ));
      final res =
          await raw.post('/auth/refresh', data: {'refresh_token': refresh});
      final body = res.data;
      final data = (body is Map && body['code'] == 0) ? body['data'] : null;
      if (data is! Map) return null;
      final access = data['access_token'] as String?;
      if (access == null || access.isEmpty) return null;
      await _tokens.onTokensRefreshed(
          access, data['refresh_token'] as String?);
      return access;
    } catch (_) {
      return null;
    }
  }

  /// 把 Dio 层错误统一转成 [ApiException] 再抛出。
  Future<T> _guard<T>(Future<Response<dynamic>> Function() send) async {
    try {
      final res = await send();
      return res.data as T;
    } on DioException catch (e) {
      final inner = e.error;
      final ex = inner is ApiException ? inner : ApiException.fromDio(e);
      // 记录到本地日志(脱敏在 AppLogger 内完成),便于用户导出反馈。
      final m = e.requestOptions.method;
      final p = e.requestOptions.path;
      AppLogger.instance.warn('API $m $p -> $ex');
      throw ex;
    }
  }

  Future<T> get<T>(String path, {Map<String, dynamic>? query}) =>
      _guard<T>(() => _dio.get(path, queryParameters: query));

  Future<T> post<T>(String path, {Object? data, Map<String, dynamic>? query}) =>
      _guard<T>(() => _dio.post(path, data: data, queryParameters: query));

  Future<T> put<T>(String path, {Object? data}) =>
      _guard<T>(() => _dio.put(path, data: data));

  Future<T> patch<T>(String path, {Object? data}) =>
      _guard<T>(() => _dio.patch(path, data: data));

  Future<T> delete<T>(String path, {Object? data}) =>
      _guard<T>(() => _dio.delete(path, data: data));

  /// 打开一个 SSE / 流式 POST 的字节流(供测试连接等需要实时展示过程的接口)。
  /// 鉴权头由请求拦截器注入;调用方负责解码与按行解析。
  Future<Stream<List<int>>> openByteStream(String path, {Object? data}) async {
    final res = await _dio.post<ResponseBody>(
      path,
      data: data,
      options: Options(
        responseType: ResponseType.stream,
        headers: {'Accept': 'text/event-stream'},
      ),
    );
    return res.data!.stream.cast<List<int>>();
  }
}
