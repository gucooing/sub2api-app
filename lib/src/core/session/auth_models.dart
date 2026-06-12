import 'package:flutter/foundation.dart';

/// 当前登录用户(后端 User 的客户端裁剪版,只保留客户端关心的字段)。
@immutable
class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
    required this.balance,
    this.concurrency = 0,
    this.status = 'active',
    this.createdAt,
  });

  final int id;
  final String username;
  final String email;

  /// 'admin' | 'user'
  final String role;
  final double balance;
  final int concurrency;
  final String status;
  final DateTime? createdAt;

  bool get isAdmin => role == 'admin';

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: (json['id'] as num).toInt(),
        username: json['username'] as String? ?? '',
        email: json['email'] as String? ?? '',
        role: json['role'] as String? ?? 'user',
        balance: (json['balance'] as num?)?.toDouble() ?? 0,
        concurrency: (json['concurrency'] as num?)?.toInt() ?? 0,
        status: json['status'] as String? ?? 'active',
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
      );
}

/// 登录第一步的结果:成功,或需要 TOTP 两步验证。
sealed class LoginOutcome {
  const LoginOutcome();
}

class LoginSuccess extends LoginOutcome {
  const LoginSuccess(this.user);

  final AppUser user;
}

class LoginNeedsTotp extends LoginOutcome {
  const LoginNeedsTotp({required this.tempToken, this.maskedEmail});

  final String tempToken;
  final String? maskedEmail;
}

/// `GET /settings/public` 中客户端关心的开关(无需登录)。
@immutable
class PublicSettingsLite {
  const PublicSettingsLite({
    required this.registrationEnabled,
    required this.emailVerifyEnabled,
    required this.turnstileEnabled,
    required this.passwordResetEnabled,
    required this.promoCodeEnabled,
    required this.invitationCodeEnabled,
    this.siteName = '',
    this.version = '',
  });

  final bool registrationEnabled;
  final bool emailVerifyEnabled;
  final bool turnstileEnabled;
  final bool passwordResetEnabled;
  final bool promoCodeEnabled;
  final bool invitationCodeEnabled;
  final String siteName;
  final String version;

  factory PublicSettingsLite.fromJson(Map<String, dynamic> json) =>
      PublicSettingsLite(
        registrationEnabled: json['registration_enabled'] as bool? ?? false,
        emailVerifyEnabled: json['email_verify_enabled'] as bool? ?? false,
        turnstileEnabled: json['turnstile_enabled'] as bool? ?? false,
        passwordResetEnabled: json['password_reset_enabled'] as bool? ?? false,
        promoCodeEnabled: json['promo_code_enabled'] as bool? ?? false,
        invitationCodeEnabled:
            json['invitation_code_enabled'] as bool? ?? false,
        siteName: json['site_name'] as String? ?? '',
        version: json['version'] as String? ?? '',
      );
}
