import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';

import '../../i18n/app_localizations.dart';

/// 统一的 API 异常。所有网络/协议/业务错误最终都归一为本类型。
///
/// 文案策略:后端返回的 message 优先([serverMessage]),否则用 [messageKey]
/// 对应的本地化文案 —— 界面层统一调用 [localizedMessage] 展示。
class ApiException implements Exception {
  const ApiException({
    required this.kind,
    this.serverMessage,
    this.statusCode,
    this.businessCode,
  });

  final ApiExceptionKind kind;

  /// 后端提供的人类可读错误信息(可能已按 Accept-Language 本地化)。
  final String? serverMessage;

  /// HTTP 状态码(协议层错误时存在)。
  final int? statusCode;

  /// 后端业务错误码(封套 code 非 0,或错误体内的 code 字段)。
  final Object? businessCode;

  bool get isUnauthorized => statusCode == 401;

  /// 本地化兜底文案的 i18n 键。
  String get messageKey {
    switch (kind) {
      case ApiExceptionKind.network:
        return 'errors.network';
      case ApiExceptionKind.timeout:
        return 'errors.timeout';
      case ApiExceptionKind.cancelled:
        return 'errors.cancelled';
      case ApiExceptionKind.http:
        return 'errors.http';
      case ApiExceptionKind.business:
        return 'errors.business';
    }
  }

  /// 界面展示用:服务端信息优先,否则本地化兜底。
  String localizedMessage(BuildContext context) {
    final m = serverMessage;
    if (m != null && m.isNotEmpty) return m;
    return context.tr(messageKey,
        params: {'status': '${statusCode ?? businessCode ?? ''}'});
  }

  /// 从 Dio 异常归一。
  factory ApiException.fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException(kind: ApiExceptionKind.timeout);
      case DioExceptionType.cancel:
        return const ApiException(kind: ApiExceptionKind.cancelled);
      case DioExceptionType.badResponse:
        final res = e.response;
        final body = res?.data;
        String? message;
        Object? code;
        if (body is Map) {
          // 后端错误体常见形态:{code,message} 或 {detail}
          final m = body['message'] ?? body['detail'];
          if (m is String && m.isNotEmpty) message = m;
          code = body['code'];
        }
        return ApiException(
          kind: ApiExceptionKind.http,
          statusCode: res?.statusCode,
          businessCode: code,
          serverMessage: message,
        );
      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return const ApiException(kind: ApiExceptionKind.network);
    }
  }

  @override
  String toString() =>
      'ApiException($kind, status=$statusCode, code=$businessCode, $serverMessage)';
}

enum ApiExceptionKind {
  /// 无法建立连接/证书错误等
  network,

  /// 超时
  timeout,

  /// HTTP 协议层错误(4xx/5xx)
  http,

  /// 封套 code 非 0 的业务错误
  business,

  /// 主动取消
  cancelled,
}
