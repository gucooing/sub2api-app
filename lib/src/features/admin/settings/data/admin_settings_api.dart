import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';

/// 服务端系统设置(管理端可编辑的常用子集)。
///
/// 后端 `GET/PUT /admin/settings` 字段众多;移动端聚焦最常调整的开关与站点信息,
/// PUT 为部分更新(只提交本页管理的字段,其余保持不变)。
@immutable
class AdminSettings {
  const AdminSettings({
    required this.siteName,
    required this.siteSubtitle,
    required this.contactInfo,
    required this.docUrl,
    required this.registrationEnabled,
    required this.emailVerifyEnabled,
    required this.passwordResetEnabled,
    required this.invitationCodeEnabled,
    required this.promoCodeEnabled,
    required this.totpEnabled,
    required this.turnstileEnabled,
    required this.defaultBalance,
    required this.defaultConcurrency,
    required this.defaultUserRpmLimit,
  });

  final String siteName;
  final String siteSubtitle;
  final String contactInfo;
  final String docUrl;

  final bool registrationEnabled;
  final bool emailVerifyEnabled;
  final bool passwordResetEnabled;
  final bool invitationCodeEnabled;
  final bool promoCodeEnabled;
  final bool totpEnabled;
  final bool turnstileEnabled;

  final double defaultBalance;
  final int defaultConcurrency;
  final int defaultUserRpmLimit;

  factory AdminSettings.fromJson(Map<String, dynamic> json) {
    bool asBool(String k) => json[k] == true;
    String asStr(String k) => json[k] as String? ?? '';
    return AdminSettings(
      siteName: asStr('site_name'),
      siteSubtitle: asStr('site_subtitle'),
      contactInfo: asStr('contact_info'),
      docUrl: asStr('doc_url'),
      registrationEnabled: asBool('registration_enabled'),
      emailVerifyEnabled: asBool('email_verify_enabled'),
      passwordResetEnabled: asBool('password_reset_enabled'),
      invitationCodeEnabled: asBool('invitation_code_enabled'),
      promoCodeEnabled: asBool('promo_code_enabled'),
      totpEnabled: asBool('totp_enabled'),
      turnstileEnabled: asBool('turnstile_enabled'),
      defaultBalance: (json['default_balance'] as num?)?.toDouble() ?? 0,
      defaultConcurrency: (json['default_concurrency'] as num?)?.toInt() ?? 0,
      defaultUserRpmLimit:
          (json['default_user_rpm_limit'] as num?)?.toInt() ?? 0,
    );
  }

  /// 仅本页管理的字段(部分更新提交)。
  Map<String, dynamic> toUpdateJson() => {
        'site_name': siteName,
        'site_subtitle': siteSubtitle,
        'contact_info': contactInfo,
        'doc_url': docUrl,
        'registration_enabled': registrationEnabled,
        'email_verify_enabled': emailVerifyEnabled,
        'password_reset_enabled': passwordResetEnabled,
        'invitation_code_enabled': invitationCodeEnabled,
        'promo_code_enabled': promoCodeEnabled,
        'totp_enabled': totpEnabled,
        'turnstile_enabled': turnstileEnabled,
        'default_balance': defaultBalance,
        'default_concurrency': defaultConcurrency,
        'default_user_rpm_limit': defaultUserRpmLimit,
      };

  AdminSettings copyWith({
    String? siteName,
    String? siteSubtitle,
    String? contactInfo,
    String? docUrl,
    bool? registrationEnabled,
    bool? emailVerifyEnabled,
    bool? passwordResetEnabled,
    bool? invitationCodeEnabled,
    bool? promoCodeEnabled,
    bool? totpEnabled,
    bool? turnstileEnabled,
    double? defaultBalance,
    int? defaultConcurrency,
    int? defaultUserRpmLimit,
  }) =>
      AdminSettings(
        siteName: siteName ?? this.siteName,
        siteSubtitle: siteSubtitle ?? this.siteSubtitle,
        contactInfo: contactInfo ?? this.contactInfo,
        docUrl: docUrl ?? this.docUrl,
        registrationEnabled: registrationEnabled ?? this.registrationEnabled,
        emailVerifyEnabled: emailVerifyEnabled ?? this.emailVerifyEnabled,
        passwordResetEnabled: passwordResetEnabled ?? this.passwordResetEnabled,
        invitationCodeEnabled:
            invitationCodeEnabled ?? this.invitationCodeEnabled,
        promoCodeEnabled: promoCodeEnabled ?? this.promoCodeEnabled,
        totpEnabled: totpEnabled ?? this.totpEnabled,
        turnstileEnabled: turnstileEnabled ?? this.turnstileEnabled,
        defaultBalance: defaultBalance ?? this.defaultBalance,
        defaultConcurrency: defaultConcurrency ?? this.defaultConcurrency,
        defaultUserRpmLimit: defaultUserRpmLimit ?? this.defaultUserRpmLimit,
      );
}

/// 管理端系统设置 API。
class AdminSettingsApi {
  AdminSettingsApi(this._client);

  final ApiClient _client;

  Future<AdminSettings> get() async {
    final data = await _client.get<dynamic>('/admin/settings');
    return AdminSettings.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 部分更新(只提交本页管理字段)。
  Future<AdminSettings> update(AdminSettings settings) async {
    final data =
        await _client.put<dynamic>('/admin/settings', data: settings.toUpdateJson());
    return AdminSettings.fromJson((data as Map).cast<String, dynamic>());
  }
}
