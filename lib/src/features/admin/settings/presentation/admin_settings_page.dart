import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../i18n/app_localizations.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../shared/widgets/error_retry.dart';
import '../../../../shared/widgets/responsive.dart';
import '../../../../shared/widgets/section_header.dart';
import '../data/admin_settings_api.dart';
import '../providers/admin_settings_providers.dart';

/// 服务端系统设置:站点信息 / 注册与登录开关 / 默认值。部分更新提交。
class AdminSettingsPage extends ConsumerWidget {
  const AdminSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('admin.settings.title'))),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorRetryView(
          error: e,
          onRetry: () => ref.invalidate(adminSettingsProvider),
        ),
        data: (settings) => _SettingsForm(initial: settings),
      ),
    );
  }
}

class _SettingsForm extends ConsumerStatefulWidget {
  const _SettingsForm({required this.initial});

  final AdminSettings initial;

  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  late final TextEditingController _siteName;
  late final TextEditingController _siteSubtitle;
  late final TextEditingController _contact;
  late final TextEditingController _docUrl;
  late final TextEditingController _balance;
  late final TextEditingController _concurrency;
  late final TextEditingController _rpm;

  late bool _registration;
  late bool _emailVerify;
  late bool _passwordReset;
  late bool _invitation;
  late bool _promo;
  late bool _totp;
  late bool _turnstile;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.initial;
    _siteName = TextEditingController(text: s.siteName);
    _siteSubtitle = TextEditingController(text: s.siteSubtitle);
    _contact = TextEditingController(text: s.contactInfo);
    _docUrl = TextEditingController(text: s.docUrl);
    _balance = TextEditingController(text: _trimNum(s.defaultBalance));
    _concurrency = TextEditingController(text: '${s.defaultConcurrency}');
    _rpm = TextEditingController(text: '${s.defaultUserRpmLimit}');
    _registration = s.registrationEnabled;
    _emailVerify = s.emailVerifyEnabled;
    _passwordReset = s.passwordResetEnabled;
    _invitation = s.invitationCodeEnabled;
    _promo = s.promoCodeEnabled;
    _totp = s.totpEnabled;
    _turnstile = s.turnstileEnabled;
  }

  static String _trimNum(double v) =>
      v == v.roundToDouble() ? '${v.toInt()}' : '$v';

  @override
  void dispose() {
    for (final c in [
      _siteName,
      _siteSubtitle,
      _contact,
      _docUrl,
      _balance,
      _concurrency,
      _rpm,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final next = widget.initial.copyWith(
      siteName: _siteName.text.trim(),
      siteSubtitle: _siteSubtitle.text.trim(),
      contactInfo: _contact.text.trim(),
      docUrl: _docUrl.text.trim(),
      registrationEnabled: _registration,
      emailVerifyEnabled: _emailVerify,
      passwordResetEnabled: _passwordReset,
      invitationCodeEnabled: _invitation,
      promoCodeEnabled: _promo,
      totpEnabled: _totp,
      turnstileEnabled: _turnstile,
      defaultBalance: double.tryParse(_balance.text.trim()) ?? 0,
      defaultConcurrency: int.tryParse(_concurrency.text.trim()) ?? 0,
      defaultUserRpmLimit: int.tryParse(_rpm.text.trim()) ?? 0,
    );
    try {
      await ref.read(adminSettingsApiProvider).update(next);
      ref.invalidate(adminSettingsProvider);
      if (mounted) showAppToast(context, context.tr('admin.settings.saved'));
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.localizedMessage(context), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveCenter(
      maxWidth: 640,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          SectionHeader(title: context.tr('admin.settings.site')),
          _field(_siteName, context.tr('admin.settings.siteName')),
          _field(_siteSubtitle, context.tr('admin.settings.siteSubtitle')),
          _field(_contact, context.tr('admin.settings.contact')),
          _field(_docUrl, context.tr('admin.settings.docUrl')),
          const SizedBox(height: 12),
          SectionHeader(title: context.tr('admin.settings.registerLogin')),
          _switch(context.tr('admin.settings.registration'), _registration,
              (v) => setState(() => _registration = v)),
          _switch(context.tr('admin.settings.emailVerify'), _emailVerify,
              (v) => setState(() => _emailVerify = v)),
          _switch(context.tr('admin.settings.passwordReset'), _passwordReset,
              (v) => setState(() => _passwordReset = v)),
          _switch(context.tr('admin.settings.invitation'), _invitation,
              (v) => setState(() => _invitation = v)),
          _switch(context.tr('admin.settings.promo'), _promo,
              (v) => setState(() => _promo = v)),
          _switch(context.tr('admin.settings.totp'), _totp,
              (v) => setState(() => _totp = v)),
          _switch(context.tr('admin.settings.turnstile'), _turnstile,
              (v) => setState(() => _turnstile = v)),
          const SizedBox(height: 12),
          SectionHeader(title: context.tr('admin.settings.defaults')),
          _field(_balance, context.tr('admin.settings.defaultBalance'),
              number: true),
          _field(_concurrency, context.tr('admin.settings.defaultConcurrency'),
              number: true),
          _field(_rpm, context.tr('admin.settings.defaultRpm'), number: true),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.tr('common.save')),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label, {bool number = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        enabled: !_saving,
        keyboardType: number ? TextInputType.number : null,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  Widget _switch(String label, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      value: value,
      onChanged: _saving ? null : onChanged,
    );
  }
}
