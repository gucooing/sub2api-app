import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/server/server_profile.dart';
import '../../core/server/server_store.dart';
import '../../core/session/auth_api.dart';
import '../../core/session/session_controller.dart';
import '../../i18n/app_localizations.dart';
import '../../shared/widgets/app_toast.dart';

/// 注册页。字段按服务器公开设置动态展示:
/// 邮箱验证码(email_verify_enabled)、优惠码、邀请码;注册成功即登录(建账号)。
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key, this.serverId});

  /// 目标服务器(由登录页传入);为空时回退到激活服务器。
  final String? serverId;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _promo = TextEditingController();
  final _invitation = TextEditingController();

  bool _busy = false;
  String? _error;
  int _resendIn = 0;
  Timer? _timer;

  ServerProfile _server() {
    final servers = ref.read(serverStoreProvider).servers;
    for (final s in servers) {
      if (s.id == widget.serverId) return s;
    }
    return ref.read(activeServerProvider);
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in [_email, _code, _password, _confirm, _promo, _invitation]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_email.text.trim().isEmpty || !_email.text.contains('@')) {
      setState(() => _error = context.tr('auth.emailInvalid'));
      return;
    }
    setState(() => _error = null);
    try {
      final res = await ref
          .read(authApiForServerProvider(_server()))
          .sendVerifyCode(_email.text.trim());
      final countdown = (res['countdown'] as num?)?.toInt() ?? 60;
      if (mounted) showAppToast(context, context.tr('auth.verifyCodeSent'));
      setState(() => _resendIn = countdown);
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        setState(() {
          _resendIn -= 1;
          if (_resendIn <= 0) t.cancel();
        });
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.localizedMessage(context));
    }
  }

  Future<void> _submit(bool needVerifyCode) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(sessionControllerProvider.notifier).register(
            _server(),
            email: _email.text.trim(),
            password: _password.text,
            verifyCode: needVerifyCode ? _code.text.trim() : null,
            promoCode: _promo.text.trim(),
            invitationCode: _invitation.text.trim(),
          );
      if (mounted) context.go('/dashboard');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.localizedMessage(context));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(publicSettingsForServerProvider(_server()));

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('auth.registerTitle'))),
      body: settings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              e is ApiException
                  ? e.localizedMessage(context)
                  : context.tr('errors.network'),
            ),
          ),
        ),
        data: (s) {
          if (!s.registrationEnabled) {
            return Center(
              child: Text(context.tr('auth.registrationDisabled')),
            );
          }
          return _buildForm(
            needVerifyCode: s.emailVerifyEnabled,
            showPromo: s.promoCodeEnabled,
            showInvitation: s.invitationCodeEnabled,
            turnstile: s.turnstileEnabled,
          );
        },
      ),
    );
  }

  Widget _buildForm({
    required bool needVerifyCode,
    required bool showPromo,
    required bool showInvitation,
    required bool turnstile,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (turnstile) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      context.tr('auth.turnstileWarning'),
                      style: TextStyle(
                        color:
                            Theme.of(context).colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _email,
                  enabled: !_busy,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: context.tr('auth.email'),
                    prefixIcon: const Icon(Icons.mail_outline),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || !v.contains('@'))
                      ? context.tr('auth.emailInvalid')
                      : null,
                ),
                if (needVerifyCode) ...[
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _code,
                          enabled: !_busy,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: context.tr('auth.verifyCode'),
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? context.tr('auth.verifyCodeRequired')
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        height: 56,
                        child: OutlinedButton(
                          onPressed:
                              (_busy || _resendIn > 0) ? null : _sendCode,
                          child: Text(
                            _resendIn > 0
                                ? context.tr('auth.resendIn',
                                    params: {'seconds': '$_resendIn'})
                                : context.tr('auth.sendCode'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _password,
                  enabled: !_busy,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: context.tr('auth.password'),
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.length < 6)
                      ? context.tr('auth.passwordTooShort')
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirm,
                  enabled: !_busy,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: context.tr('auth.passwordConfirm'),
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) => (v != _password.text)
                      ? context.tr('auth.passwordMismatch')
                      : null,
                ),
                if (showPromo) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _promo,
                    enabled: !_busy,
                    decoration: InputDecoration(
                      labelText:
                          '${context.tr('auth.promoCode')} (${context.tr('common.optional')})',
                      prefixIcon: const Icon(Icons.card_giftcard_outlined),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
                if (showInvitation) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _invitation,
                    enabled: !_busy,
                    decoration: InputDecoration(
                      labelText:
                          '${context.tr('auth.invitationCode')} (${context.tr('common.optional')})',
                      prefixIcon: const Icon(Icons.key_outlined),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : () => _submit(needVerifyCode),
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(context.tr('auth.registerButton')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
