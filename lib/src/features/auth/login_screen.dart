import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/server/server_store.dart';
import '../../core/session/auth_models.dart';
import '../../core/session/session_controller.dart';
import '../../core/storage/secure_store.dart';
import '../../i18n/app_localizations.dart';
import '../../shared/widgets/brand_mark.dart';

/// 登录页:邮箱+密码;后端要求时进入 TOTP 第二步。
/// AppBar 提供服务器切换入口;按公开设置展示注册入口与 Turnstile 提示。
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _totpCode = TextEditingController();

  bool _busy = false;
  String? _error;

  bool _obscurePassword = true;
  bool _rememberAccount = false;
  bool _rememberPassword = false;

  /// 非空表示处于 TOTP 第二步。
  LoginNeedsTotp? _totpChallenge;

  @override
  void initState() {
    super.initState();
    // 回填已记住的账号/密码(按当前服务器)。
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSavedCredentials());
  }

  Future<void> _loadSavedCredentials() async {
    final secure = ref.read(secureStoreProvider);
    final serverId = ref.read(activeServerProvider).id;
    final email = await secure.readSavedEmail(serverId);
    final password = await secure.readSavedPassword(serverId);
    if (!mounted || email == null || email.isEmpty) return;
    setState(() {
      _email.text = email;
      _rememberAccount = true;
      if (password != null && password.isNotEmpty) {
        _password.text = password;
        _rememberPassword = true;
      }
    });
  }

  Future<void> _persistCredentials() async {
    final secure = ref.read(secureStoreProvider);
    final serverId = ref.read(activeServerProvider).id;
    if (_rememberAccount) {
      await secure.saveCredentials(
        serverId,
        email: _email.text.trim(),
        password: _rememberPassword ? _password.text : null,
      );
    } else {
      await secure.clearCredentials(serverId);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _totpCode.dispose();
    super.dispose();
  }

  Future<void> _guarded(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.localizedMessage(context));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitLogin() async {
    if (!_formKey.currentState!.validate()) return;
    await _guarded(() async {
      final outcome = await ref
          .read(sessionControllerProvider.notifier)
          .login(_email.text.trim(), _password.text);
      // 走到这里说明密码已通过校验(成功或进入 TOTP 第二步),按勾选持久化凭据。
      await _persistCredentials();
      if (outcome is LoginNeedsTotp && mounted) {
        setState(() => _totpChallenge = outcome);
      }
      // LoginSuccess 由路由守卫自动跳转
    });
  }

  Future<void> _submitTotp() async {
    final code = _totpCode.text.trim();
    if (code.length != 6) return;
    await _guarded(() => ref
        .read(sessionControllerProvider.notifier)
        .submitTotp(_totpChallenge!.tempToken, code));
  }

  @override
  Widget build(BuildContext context) {
    final server = ref.watch(activeServerProvider);
    final settings = ref.watch(publicSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('auth.login')),
        actions: [
          IconButton(
            tooltip: context.tr('servers.title'),
            icon: const Icon(Icons.dns_outlined),
            onPressed: _busy ? null : () => context.push('/servers'),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: _totpChallenge == null
                ? _buildLoginForm(server.name, settings)
                : _buildTotpForm(),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm(
      String serverName, AsyncValue<PublicSettingsLite> settings) {
    final turnstileEnabled = settings.value?.turnstileEnabled ?? false;
    final registrationEnabled = settings.value?.registrationEnabled ?? false;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: BrandMark(size: 72)),
          const SizedBox(height: 12),
          Center(
            child: Text(
              serverName,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          const SizedBox(height: 24),
          if (turnstileEnabled) ...[
            _InfoBanner(text: context.tr('auth.turnstileWarning')),
            const SizedBox(height: 16),
          ],
          if (_error != null) ...[
            _ErrorBanner(text: _error!),
            const SizedBox(height: 16),
          ],
          TextFormField(
            controller: _email,
            enabled: !_busy,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: InputDecoration(
              labelText: context.tr('auth.email'),
              prefixIcon: const Icon(Icons.mail_outline),
              border: const OutlineInputBorder(),
            ),
            validator: (v) => (v == null || !v.contains('@'))
                ? context.tr('auth.emailInvalid')
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _password,
            enabled: !_busy,
            obscureText: _obscurePassword,
            autofillHints: const [AutofillHints.password],
            onFieldSubmitted: (_) => _submitLogin(),
            decoration: InputDecoration(
              labelText: context.tr('auth.password'),
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                tooltip: context.tr(
                    _obscurePassword ? 'auth.showPassword' : 'auth.hidePassword'),
                icon: Icon(_obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
                onPressed: _busy
                    ? null
                    : () =>
                        setState(() => _obscurePassword = !_obscurePassword),
              ),
              border: const OutlineInputBorder(),
            ),
            validator: (v) => (v == null || v.isEmpty)
                ? context.tr('auth.passwordRequired')
                : null,
          ),
          const SizedBox(height: 8),
          // 记住账号 / 记住密码(记住密码隐含记住账号)。
          Row(
            children: [
              Expanded(
                child: _RememberCheck(
                  label: context.tr('auth.rememberAccount'),
                  value: _rememberAccount,
                  onChanged: _busy
                      ? null
                      : (v) => setState(() {
                            _rememberAccount = v;
                            if (!v) _rememberPassword = false;
                          }),
                ),
              ),
              Expanded(
                child: _RememberCheck(
                  label: context.tr('auth.rememberPassword'),
                  value: _rememberPassword,
                  onChanged: _busy
                      ? null
                      : (v) => setState(() {
                            _rememberPassword = v;
                            if (v) _rememberAccount = true;
                          }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _submitLogin,
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.tr('auth.loginButton')),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (registrationEnabled)
                TextButton(
                  onPressed: _busy ? null : () => context.push('/register'),
                  child: Text(context.tr('auth.register')),
                )
              else
                const SizedBox.shrink(),
              TextButton(
                onPressed: _busy ? null : _showForgotPassword,
                child: Text(context.tr('auth.forgotPassword')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTotpForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: BrandMark(size: 72)),
        const SizedBox(height: 24),
        Text(
          context.tr('auth.totpTitle'),
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          context.tr('auth.totpHint',
              params: {'email': _totpChallenge?.maskedEmail ?? ''}),
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        if (_error != null) ...[
          _ErrorBanner(text: _error!),
          const SizedBox(height: 16),
        ],
        TextField(
          controller: _totpCode,
          enabled: !_busy,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(letterSpacing: 8),
          onSubmitted: (_) => _submitTotp(),
          decoration: InputDecoration(
            counterText: '',
            hintText: '000000',
            border: const OutlineInputBorder(),
            labelText: context.tr('auth.totpCode'),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _busy ? null : _submitTotp,
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(context.tr('auth.totpButton')),
        ),
        TextButton(
          onPressed: _busy
              ? null
              : () => setState(() {
                    _totpChallenge = null;
                    _totpCode.clear();
                    _error = null;
                  }),
          child: Text(context.tr('common.back')),
        ),
      ],
    );
  }

  void _showForgotPassword() {
    final origin = ref.read(activeServerProvider).baseUrl;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('auth.forgotPassword')),
        content: Text(
          context.tr('auth.forgotPasswordHint', params: {'url': origin}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.tr('common.ok')),
          ),
        ],
      ),
    );
  }
}

class _RememberCheck extends StatelessWidget {
  const _RememberCheck({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: value,
                onChanged: onChanged == null
                    ? null
                    : (v) => onChanged!(v ?? false),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(color: scheme.onErrorContainer)),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(color: scheme.onTertiaryContainer)),
    );
  }
}
