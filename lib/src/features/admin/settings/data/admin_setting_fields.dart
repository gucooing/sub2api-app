import 'package:flutter/material.dart';

/// 设置字段类型。
enum SettingFieldType { toggle, text, multiline, number }

/// 单个设置字段描述子(后端 key + 类型 + i18n 标签键)。
class SettingField {
  const SettingField(this.key, this.labelKey, this.type);

  final String key;
  final String labelKey;
  final SettingFieldType type;
}

/// 一个设置大类(对照 web 系统设置标签页)。
class SettingCategory {
  const SettingCategory({
    required this.key,
    required this.icon,
    required this.labelKey,
    required this.fields,
  });

  final String key;
  final IconData icon;
  final String labelKey;
  final List<SettingField> fields;
}

const _t = SettingFieldType.text;
const _b = SettingFieldType.toggle;
const _n = SettingFieldType.number;
const _ml = SettingFieldType.multiline;

/// 系统设置分类(对照 web SettingsView 标签):通用/安全/登录条款/功能开关/
/// 用户默认/邮件/第三方登录。仅含已确认的后端顶层标量字段,保存按类部分提交。
const List<SettingCategory> kSettingCategories = [
  SettingCategory(
    key: 'general',
    icon: Icons.home_outlined,
    labelKey: 'admin.settings.cat.general',
    fields: [
      SettingField('site_name', 'admin.settings.f.siteName', _t),
      SettingField('site_subtitle', 'admin.settings.f.siteSubtitle', _t),
      SettingField('site_logo', 'admin.settings.f.siteLogo', _t),
      SettingField('api_base_url', 'admin.settings.f.apiBaseUrl', _t),
      SettingField('contact_info', 'admin.settings.f.contact', _t),
      SettingField('doc_url', 'admin.settings.f.docUrl', _t),
      SettingField('home_content', 'admin.settings.f.homeContent', _ml),
      SettingField(
          'hide_ccs_import_button', 'admin.settings.f.hideCcsImport', _b),
      SettingField('backend_mode_enabled', 'admin.settings.f.backendMode', _b),
      SettingField(
          'table_default_page_size', 'admin.settings.f.tablePageSize', _n),
    ],
  ),
  SettingCategory(
    key: 'security',
    icon: Icons.shield_outlined,
    labelKey: 'admin.settings.cat.security',
    fields: [
      SettingField('registration_enabled', 'admin.settings.f.registration', _b),
      SettingField('email_verify_enabled', 'admin.settings.f.emailVerify', _b),
      SettingField(
          'password_reset_enabled', 'admin.settings.f.passwordReset', _b),
      SettingField(
          'invitation_code_enabled', 'admin.settings.f.invitation', _b),
      SettingField('promo_code_enabled', 'admin.settings.f.promo', _b),
      SettingField('totp_enabled', 'admin.settings.f.totp', _b),
      SettingField('turnstile_enabled', 'admin.settings.f.turnstile', _b),
      SettingField('turnstile_site_key', 'admin.settings.f.turnstileKey', _t),
      SettingField('force_email_on_third_party_signup',
          'admin.settings.f.forceEmail', _b),
      SettingField('api_key_acl_trust_forwarded_ip',
          'admin.settings.f.trustForwardedIp', _b),
      SettingField('frontend_url', 'admin.settings.f.frontendUrl', _t),
    ],
  ),
  SettingCategory(
    key: 'agreement',
    icon: Icons.description_outlined,
    labelKey: 'admin.settings.cat.agreement',
    fields: [
      SettingField(
          'login_agreement_enabled', 'admin.settings.f.agreementEnabled', _b),
      SettingField('login_agreement_mode', 'admin.settings.f.agreementMode', _t),
    ],
  ),
  SettingCategory(
    key: 'features',
    icon: Icons.bolt_outlined,
    labelKey: 'admin.settings.cat.features',
    fields: [
      SettingField('payment_enabled', 'admin.settings.f.payment', _b),
      SettingField('linuxdo_connect_enabled', 'admin.settings.f.linuxdo', _b),
      SettingField('dingtalk_connect_enabled', 'admin.settings.f.dingtalk', _b),
      SettingField('wechat_connect_enabled', 'admin.settings.f.wechat', _b),
      SettingField('oidc_connect_enabled', 'admin.settings.f.oidc', _b),
    ],
  ),
  SettingCategory(
    key: 'users',
    icon: Icons.people_outline,
    labelKey: 'admin.settings.cat.users',
    fields: [
      SettingField('default_balance', 'admin.settings.f.defaultBalance', _n),
      SettingField(
          'default_concurrency', 'admin.settings.f.defaultConcurrency', _n),
      SettingField(
          'default_user_rpm_limit', 'admin.settings.f.defaultRpm', _n),
      SettingField(
          'affiliate_rebate_rate', 'admin.settings.f.rebateRate', _n),
      SettingField('affiliate_rebate_freeze_hours',
          'admin.settings.f.rebateFreeze', _n),
      SettingField('affiliate_rebate_duration_days',
          'admin.settings.f.rebateDuration', _n),
      SettingField('affiliate_rebate_per_invitee_cap',
          'admin.settings.f.rebateCap', _n),
    ],
  ),
  SettingCategory(
    key: 'email',
    icon: Icons.mail_outline,
    labelKey: 'admin.settings.cat.email',
    fields: [
      SettingField('smtp_host', 'admin.settings.f.smtpHost', _t),
      SettingField('smtp_port', 'admin.settings.f.smtpPort', _n),
      SettingField('smtp_username', 'admin.settings.f.smtpUsername', _t),
      SettingField('smtp_from_email', 'admin.settings.f.smtpFrom', _t),
      SettingField('smtp_from_name', 'admin.settings.f.smtpFromName', _t),
      SettingField('smtp_use_tls', 'admin.settings.f.smtpTls', _b),
    ],
  ),
];
