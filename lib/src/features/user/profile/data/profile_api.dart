import '../../../../core/network/api_client.dart';

/// 区分「不修改该字段」与「显式置空」的哨兵。
const Object _unset = Object();

/// 个人资料相关 API(修改密码、TOTP 管理)。
class ProfileApi {
  ProfileApi(this._client);

  final ApiClient _client;

  /// 更新资料(用户名/头像/余额提醒)。只传非 null 字段。
  Future<void> updateProfile({
    String? username,
    Object? avatarUrl = _unset,
    bool? balanceNotifyEnabled,
    Object? balanceNotifyThreshold = _unset,
  }) async {
    final body = <String, dynamic>{
      'username': ?username,
      if (!identical(avatarUrl, _unset)) 'avatar_url': avatarUrl,
      'balance_notify_enabled': ?balanceNotifyEnabled,
      if (!identical(balanceNotifyThreshold, _unset))
        'balance_notify_threshold': balanceNotifyThreshold,
    };
    await _client.put<dynamic>('/user', data: body);
  }

  /// 当前账号的登录方式绑定状态。
  Future<List<IdentityBinding>> identityBindings() async {
    final data = await _client.get<dynamic>('/user/profile');
    final map = (data as Map).cast<String, dynamic>();
    return IdentityBinding.fromUserJson(map);
  }

  /// 发送邮箱绑定验证码。
  Future<void> sendEmailBindingCode(String email) async {
    await _client.post<dynamic>('/user/account-bindings/email/send-code',
        data: {'email': email});
  }

  /// 绑定邮箱身份(需验证码 + 当前账号密码,与 web 一致)。
  Future<void> bindEmail({
    required String email,
    required String verifyCode,
    required String password,
  }) async {
    await _client.post<dynamic>('/user/account-bindings/email', data: {
      'email': email,
      'verify_code': verifyCode,
      'password': password,
    });
  }

  /// 解绑某登录方式(linuxdo/dingtalk/oidc/wechat/email)。
  Future<void> unbindIdentity(String provider) async {
    await _client.delete<dynamic>('/user/account-bindings/$provider');
  }

  /// 准备第三方绑定:在后端写入「绑定当前用户」的临时令牌(对齐 web
  /// `prepareOAuthBindAccessTokenCookie`),随后再打开 bind/start 链接。
  Future<void> prepareOAuthBindToken() async {
    await _client.post<dynamic>('/auth/oauth/bind-token');
  }

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

/// 登录方式绑定状态。
class IdentityBinding {
  const IdentityBinding({
    required this.provider,
    required this.bound,
    this.canBind = true,
    this.canUnbind = false,
  });

  /// email / linuxdo / dingtalk / oidc / wechat
  final String provider;
  final bool bound;

  /// 服务端是否允许绑定/解绑(后端按「至少保留一种登录方式」等规则下发)。
  final bool canBind;
  final bool canUnbind;

  /// 支持展示的登录方式(顺序即展示顺序),与 web 对齐。
  static const providers = ['email', 'linuxdo', 'dingtalk', 'oidc', 'wechat'];

  static List<IdentityBinding> fromUserJson(Map<String, dynamic> json) {
    Map<String, dynamic>? detailOf(String p) {
      final map = json['auth_bindings'] ?? json['identity_bindings'];
      if (map is Map && map[p] is Map) {
        return (map[p] as Map).cast<String, dynamic>();
      }
      return null;
    }

    bool boundOf(String p) {
      final direct = json['${p}_bound'];
      if (direct is bool) return direct;
      final map = json['auth_bindings'] ?? json['identity_bindings'];
      if (map is Map) {
        final v = map[p];
        if (v is bool) return v;
        if (v is Map) return v['bound'] == true;
      }
      return false;
    }

    return [
      for (final p in providers)
        () {
          final bound = boundOf(p);
          final d = detailOf(p);
          // email 由专用流程绑定、且不可解绑(主登录方式)。
          if (p == 'email') {
            return IdentityBinding(
                provider: p, bound: bound, canBind: false, canUnbind: false);
          }
          return IdentityBinding(
            provider: p,
            bound: bound,
            canBind: d?['can_bind'] as bool? ?? true,
            canUnbind: bound && (d?['can_unbind'] as bool? ?? false),
          );
        }(),
    ];
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
