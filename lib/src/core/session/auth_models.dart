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
    this.avatarUrl,
    this.balanceNotifyEnabled = false,
    this.balanceNotifyThreshold,
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
  final String? avatarUrl;

  /// 余额不足提醒开关与阈值。
  final bool balanceNotifyEnabled;
  final double? balanceNotifyThreshold;

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
        avatarUrl: json['avatar_url'] as String?,
        balanceNotifyEnabled: json['balance_notify_enabled'] as bool? ?? false,
        balanceNotifyThreshold:
            (json['balance_notify_threshold'] as num?)?.toDouble(),
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

/// 管理员配置的自定义菜单项(自定义页面)。
///
/// 既可能是纯外链(`url` 为 http(s)),也可能是内置 markdown 内容页
/// (`pageSlug` 非空,或 `url` 以 `md:` 开头)。
@immutable
class CustomMenuItem {
  const CustomMenuItem({
    required this.id,
    required this.label,
    this.iconSvg = '',
    this.url = '',
    this.pageSlug,
    this.visibility = 'user',
    this.sortOrder = 0,
  });

  final String id;
  final String label;
  final String iconSvg;
  final String url;
  final String? pageSlug;

  /// 'user' | 'admin'
  final String visibility;
  final int sortOrder;

  /// 是否为内置 markdown 内容页(需经 Web `/custom/{id}` 渲染),
  /// 否则视为可直接打开的外链。
  bool get isMarkdown =>
      (pageSlug != null && pageSlug!.isNotEmpty) || url.startsWith('md:');

  factory CustomMenuItem.fromJson(Map<String, dynamic> json) => CustomMenuItem(
        id: json['id']?.toString() ?? '',
        label: json['label'] as String? ?? '',
        iconSvg: json['icon_svg'] as String? ?? '',
        url: json['url'] as String? ?? '',
        pageSlug: json['page_slug'] as String?,
        visibility: json['visibility'] as String? ?? 'user',
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      );
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
    this.paymentEnabled = false,
    this.affiliateEnabled = false,
    this.availableChannelsEnabled = false,
    this.channelMonitorEnabled = false,
    this.serviceQuotaEnabled = false,
    this.allowUserViewErrorRequests = false,
    this.linuxdoOauthEnabled = false,
    this.oidcOauthEnabled = false,
    this.githubOauthEnabled = false,
    this.googleOauthEnabled = false,
    this.wechatOauthEnabled = false,
    this.customMenuItems = const [],
    this.siteName = '',
    this.version = '',
  });

  final bool registrationEnabled;
  final bool emailVerifyEnabled;
  final bool turnstileEnabled;
  final bool passwordResetEnabled;
  final bool promoCodeEnabled;
  final bool invitationCodeEnabled;

  // 管理员可开关的可选功能(决定用户端入口是否展示)。
  final bool paymentEnabled;
  final bool affiliateEnabled;
  final bool availableChannelsEnabled;
  final bool channelMonitorEnabled;
  final bool serviceQuotaEnabled;
  final bool allowUserViewErrorRequests;

  // 第三方登录是否开启(决定绑定设置展示哪些登录方式)。
  final bool linuxdoOauthEnabled;
  final bool oidcOauthEnabled;
  final bool githubOauthEnabled;
  final bool googleOauthEnabled;
  final bool wechatOauthEnabled;

  /// 自定义页面(已含管理员配置的可见性/排序,使用时仍按角色过滤)。
  final List<CustomMenuItem> customMenuItems;

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
        paymentEnabled: json['payment_enabled'] as bool? ?? false,
        affiliateEnabled: json['affiliate_enabled'] as bool? ?? false,
        availableChannelsEnabled:
            json['available_channels_enabled'] as bool? ?? false,
        channelMonitorEnabled:
            json['channel_monitor_enabled'] as bool? ?? false,
        serviceQuotaEnabled: json['service_quota_enabled'] as bool? ?? false,
        allowUserViewErrorRequests:
            json['allow_user_view_error_requests'] as bool? ?? false,
        linuxdoOauthEnabled: json['linuxdo_oauth_enabled'] as bool? ?? false,
        oidcOauthEnabled: json['oidc_oauth_enabled'] as bool? ?? false,
        githubOauthEnabled: json['github_oauth_enabled'] as bool? ?? false,
        googleOauthEnabled: json['google_oauth_enabled'] as bool? ?? false,
        wechatOauthEnabled: json['wechat_oauth_enabled'] as bool? ?? false,
        customMenuItems: (json['custom_menu_items'] as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .map(CustomMenuItem.fromJson)
                .toList() ??
            const [],
        siteName: json['site_name'] as String? ?? '',
        version: json['version'] as String? ?? '',
      );
}
