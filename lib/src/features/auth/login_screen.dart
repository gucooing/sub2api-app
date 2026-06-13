import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/account/account_store.dart';
import '../../core/network/api_exception.dart';
import '../../core/server/server_profile.dart';
import '../../core/server/server_store.dart';
import '../../core/session/auth_models.dart';
import '../../core/session/session_controller.dart';
import '../../core/storage/prefs_store.dart';
import '../../core/storage/secure_store.dart';
import '../../i18n/app_localizations.dart';
import '../../shared/widgets/brand_mark.dart';
import '../settings/servers_screen.dart';
import 'login_agreement.dart';

/// 登录页:选择服务器 + 邮箱密码登录(后端要求时进入 TOTP)。
/// 服务器在下拉中选择/新增;登录条款支持 checkbox 与 modal 两种形式。
/// 登录成功新增/激活账号并跳转;已登录时进入本页即「添加账号」。
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

  /// 当前选中的服务器 id。
  String? _serverId;

  /// 本会话内已同意条款(无修订号时仅本会话有效)。
  bool _agreementAcceptedLocal = false;

  /// 已为哪个服务器弹过 modal 条款(避免重复弹出)。
  String? _modalShownForServerId;

  LoginNeedsTotp? _totpChallenge;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _serverId = _defaultServerId();
      _loadSavedCredentials();
      if (mounted) setState(() {});
    });
  }

  String _defaultServerId() {
    final account = ref.read(activeAccountProvider);
    if (account != null) return account.serverId;
    return ref.read(activeServerProvider).id;
  }

  ServerProfile _selectedServer() {
    final servers = ref.read(serverStoreProvider).servers;
    for (final s in servers) {
      if (s.id == _serverId) return s;
    }
    return ref.read(activeServerProvider);
  }

  Future<void> _loadSavedCredentials() async {
    final secure = ref.read(secureStoreProvider);
    final serverId = _serverId ?? _defaultServerId();
    final email = await secure.readSavedEmail(serverId);
    final password = await secure.readSavedPassword(serverId);
    if (!mounted) return;
    setState(() {
      if (email != null && email.isNotEmpty) {
        _email.text = email;
        _rememberAccount = true;
        if (password != null && password.isNotEmpty) {
          _password.text = password;
          _rememberPassword = true;
        }
      } else {
        _email.clear();
        _password.clear();
        _rememberAccount = false;
        _rememberPassword = false;
      }
    });
  }

  Future<void> _persistCredentials(String serverId) async {
    final secure = ref.read(secureStoreProvider);
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
    final server = _selectedServer();
    await _guarded(() async {
      final outcome = await ref
          .read(sessionControllerProvider.notifier)
          .login(server, _email.text.trim(), _password.text);
      await _persistCredentials(server.id);
      if (outcome is LoginNeedsTotp && mounted) {
        setState(() => _totpChallenge = outcome);
      } else if (outcome is LoginSuccess && mounted) {
        context.go('/dashboard');
      }
    });
  }

  Future<void> _submitTotp() async {
    final code = _totpCode.text.trim();
    if (code.length != 6) return;
    final server = _selectedServer();
    await _guarded(() async {
      await ref
          .read(sessionControllerProvider.notifier)
          .submitTotp(server, _totpChallenge!.tempToken, code);
      if (mounted) context.go('/dashboard');
    });
  }

  /// 计算条款是否已接受。
  bool _agreementAccepted(PublicSettingsLite s, String serverId) {
    if (!s.agreementGateActive) return true;
    if (_agreementAcceptedLocal) return true;
    final prefs = ref.read(sharedPreferencesProvider);
    return isAgreementAccepted(prefs, serverId, s.loginAgreementRevision);
  }

  Future<void> _acceptAgreement(PublicSettingsLite s, String serverId) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await persistAgreementAccepted(prefs, serverId, s.loginAgreementRevision);
    if (mounted) setState(() => _agreementAcceptedLocal = true);
  }

  void _maybeShowModal(PublicSettingsLite s, String serverId) {
    if (s.loginAgreementMode == 'checkbox') return;
    if (!s.agreementGateActive || _agreementAccepted(s, serverId)) return;
    if (_modalShownForServerId == serverId) return;
    _modalShownForServerId = serverId;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final ok = await showAgreementModal(context, s);
      if (ok == true) _acceptAgreement(s, serverId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final server = _selectedServer();
    final settingsAsync = ref.watch(publicSettingsForServerProvider(server));

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('auth.login'))),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: _totpChallenge == null
                ? _buildLoginForm(server, settingsAsync)
                : _buildTotpForm(),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm(
      ServerProfile server, AsyncValue<PublicSettingsLite> settingsAsync) {
    final settings = settingsAsync.value;
    final turnstileEnabled = settings?.turnstileEnabled ?? false;
    final registrationEnabled = settings?.registrationEnabled ?? false;
    final gateActive = settings?.agreementGateActive ?? false;
    final accepted =
        settings == null ? true : _agreementAccepted(settings, server.id);
    final authDisabled = _busy || (gateActive && !accepted);

    if (settings != null) _maybeShowModal(settings, server.id);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: BrandMark(size: 72)),
          const SizedBox(height: 20),
          _buildServerSelector(),
          const SizedBox(height: 20),
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
            onFieldSubmitted: (_) => authDisabled ? null : _submitLogin(),
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
          // 登录条款门控。
          if (settings != null && gateActive) ...[
            const SizedBox(height: 4),
            if (settings.loginAgreementMode == 'checkbox')
              LoginAgreementCheckbox(
                documents: settings.agreementDocuments,
                accepted: accepted,
                enabled: !_busy,
                onChanged: (v) {
                  if (v) {
                    _acceptAgreement(settings, server.id);
                  } else {
                    setState(() => _agreementAcceptedLocal = false);
                  }
                },
              )
            else if (!accepted)
              _AgreementGateBanner(
                onView: () => showAgreementModal(context, settings).then((ok) {
                  if (ok == true) _acceptAgreement(settings, server.id);
                }),
              ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: authDisabled ? null : _submitLogin,
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
                  onPressed: _busy
                      ? null
                      : () => context.push('/register', extra: server.id),
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

  Widget _buildServerSelector() {
    final servers = ref.watch(serverStoreProvider).servers;
    const addValue = '__add_server__';
    return DropdownButtonFormField<String>(
      initialValue: _serverId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: context.tr('auth.selectServer'),
        prefixIcon: const Icon(Icons.dns_outlined),
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final s in servers)
          DropdownMenuItem(
            value: s.id,
            child: Text('${s.name}  ·  ${s.baseUrl}',
                overflow: TextOverflow.ellipsis),
          ),
        DropdownMenuItem(
          value: addValue,
          child: Row(
            children: [
              const Icon(Icons.add, size: 18),
              const SizedBox(width: 6),
              Text(context.tr('servers.add')),
            ],
          ),
        ),
      ],
      onChanged: _busy
          ? null
          : (value) async {
              if (value == null) return;
              if (value == addValue) {
                final store = ref.read(serverStoreProvider.notifier);
                final newId = await showServerEditDialog(context, store);
                if (newId != null) {
                  setState(() {
                    _serverId = newId;
                    _agreementAcceptedLocal = false;
                  });
                  _loadSavedCredentials();
                }
                return;
              }
              setState(() {
                _serverId = value;
                _agreementAcceptedLocal = false;
              });
              _loadSavedCredentials();
            },
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
    final origin = _selectedServer().baseUrl;
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

/// modal 模式未同意时的提示条 + 「查看条款」。
class _AgreementGateBanner extends StatelessWidget {
  const _AgreementGateBanner({required this.onView});

  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.shield_outlined, size: 20, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.tr('agreement.gateHint'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          TextButton(
            onPressed: onView,
            child: Text(context.tr('agreement.viewDocs')),
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
