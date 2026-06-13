import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../network/api_client_provider.dart';
import '../server/server_profile.dart';

/// 认证相关端点的薄封装(返回原始 Map,由会话层解析为模型,便于分别测试)。
abstract class AuthApi {
  Future<Map<String, dynamic>> login(String email, String password,
      {String? turnstileToken});

  Future<Map<String, dynamic>> login2fa(String tempToken, String totpCode);

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    String? verifyCode,
    String? promoCode,
    String? invitationCode,
  });

  Future<Map<String, dynamic>> me();

  Future<void> logout({String? refreshToken});

  Future<Map<String, dynamic>> sendVerifyCode(String email);

  Future<Map<String, dynamic>> publicSettings();
}

class HttpAuthApi implements AuthApi {
  HttpAuthApi(this._client);

  final ApiClient _client;

  @override
  Future<Map<String, dynamic>> login(String email, String password,
      {String? turnstileToken}) async {
    final data = await _client.post<dynamic>('/auth/login', data: {
      'email': email,
      'password': password,
      'turnstile_token': ?turnstileToken,
    });
    return (data as Map).cast<String, dynamic>();
  }

  @override
  Future<Map<String, dynamic>> login2fa(
      String tempToken, String totpCode) async {
    final data = await _client.post<dynamic>('/auth/login/2fa',
        data: {'temp_token': tempToken, 'totp_code': totpCode});
    return (data as Map).cast<String, dynamic>();
  }

  @override
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    String? verifyCode,
    String? promoCode,
    String? invitationCode,
  }) async {
    final data = await _client.post<dynamic>('/auth/register', data: {
      'email': email,
      'password': password,
      if (verifyCode != null && verifyCode.isNotEmpty)
        'verify_code': verifyCode,
      if (promoCode != null && promoCode.isNotEmpty) 'promo_code': promoCode,
      if (invitationCode != null && invitationCode.isNotEmpty)
        'invitation_code': invitationCode,
    });
    return (data as Map).cast<String, dynamic>();
  }

  @override
  Future<Map<String, dynamic>> me() async {
    final data = await _client.get<dynamic>('/auth/me');
    return (data as Map).cast<String, dynamic>();
  }

  @override
  Future<void> logout({String? refreshToken}) async {
    await _client.post<dynamic>('/auth/logout', data: {
      'refresh_token': ?refreshToken,
    });
  }

  @override
  Future<Map<String, dynamic>> sendVerifyCode(String email) async {
    final data = await _client
        .post<dynamic>('/auth/send-verify-code', data: {'email': email});
    return (data as Map).cast<String, dynamic>();
  }

  @override
  Future<Map<String, dynamic>> publicSettings() async {
    final data = await _client.get<dynamic>('/settings/public');
    return (data as Map).cast<String, dynamic>();
  }
}

final authApiProvider = Provider<AuthApi>(
  (ref) => HttpAuthApi(ref.watch(apiClientProvider)),
);

/// 面向指定服务器的 AuthApi(登录页选服务器后用于公开设置 + 登录,无需令牌)。
final authApiForServerProvider =
    Provider.family<AuthApi, ServerProfile>(
  (ref, server) => HttpAuthApi(ref.watch(serverApiClientProvider(server))),
);
