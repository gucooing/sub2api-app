import '../../../../core/network/api_client.dart';

/// 个人资料相关 API(修改密码、TOTP 管理)。
class ProfileApi {
  ProfileApi(this._client);

  final ApiClient _client;

  /// 修改密码。
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    await _client.put<dynamic>('/user/password', data: {
      'old_password': oldPassword,
      'new_password': newPassword,
    });
  }

  /// 获取 TOTP 状态。
  Future<TotpStatus> getTotpStatus() async {
    final data = await _client.get<dynamic>('/user/totp/status');
    return TotpStatus.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 获取 TOTP 操作的验证方式(email 或 password)。
  Future<String> getTotpVerificationMethod() async {
    final data = await _client.get<dynamic>('/user/totp/verification-method');
    return (data as Map)['method'] as String? ?? 'password';
  }

  /// 发送邮箱验证码(用于 TOTP 操作)。
  Future<void> sendTotpVerifyCode() async {
    await _client.post<dynamic>('/user/totp/send-code');
  }

  /// 初始化 TOTP 设置(生成密钥和二维码)。
  Future<TotpSetupData> initiateTotp({
    String? emailCode,
    String? password,
  }) async {
    final data = await _client.post<dynamic>('/user/totp/setup', data: {
      if (emailCode != null) 'email_code': emailCode,
      if (password != null) 'password': password,
    });
    return TotpSetupData.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 启用 TOTP(验证动态码)。
  Future<void> enableTotp({
    required String code,
    required String setupToken,
  }) async {
    await _client.post<dynamic>('/user/totp/enable', data: {
      'code': code,
      'setup_token': setupToken,
    });
  }

  /// 禁用 TOTP。
  Future<void> disableTotp({
    String? emailCode,
    String? password,
  }) async {
    await _client.post<dynamic>('/user/totp/disable', data: {
      if (emailCode != null) 'email_code': emailCode,
      if (password != null) 'password': password,
    });
  }
}

/// TOTP 状态。
class TotpStatus {
  const TotpStatus({
    required this.enabled,
    this.enabledAt,
  });

  final bool enabled;
  final DateTime? enabledAt;

  factory TotpStatus.fromJson(Map<String, dynamic> json) => TotpStatus(
        enabled: json['enabled'] as bool? ?? false,
        enabledAt: json['enabled_at'] != null
            ? DateTime.tryParse(json['enabled_at'] as String)?.toLocal()
            : null,
      );
}

/// TOTP 设置数据(初始化返回)。
class TotpSetupData {
  const TotpSetupData({
    required this.secret,
    required this.qrCodeUrl,
    required this.setupToken,
  });

  final String secret;
  final String qrCodeUrl;
  final String setupToken;

  factory TotpSetupData.fromJson(Map<String, dynamic> json) => TotpSetupData(
        secret: json['secret'] as String? ?? '',
        qrCodeUrl: json['qr_code_url'] as String? ?? '',
        setupToken: json['setup_token'] as String? ?? '',
      );
}
