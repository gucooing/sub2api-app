import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/preferences/external_browser_controller.dart';
import '../../../../core/server/server_store.dart';
import '../../../../core/session/auth_models.dart';
import '../../../../core/session/session_controller.dart';
import '../../../../i18n/app_localizations.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../data/profile_api.dart';
import '../providers/profile_providers.dart';

/// 绑定设置:查询并修改登录方式绑定(对齐 web 逻辑)。
///
/// - 邮箱:未绑定可在应用内绑定(邮箱 + 验证码 + 账号密码);邮箱为主登录方式,不可解绑。
/// - 第三方(LinuxDO/钉钉/OIDC/微信):未绑定且已开启可绑定(打开浏览器授权);
///   是否可解绑由后端 `can_unbind` 决定(保证至少保留一种登录方式)。
class BindingsPage extends ConsumerWidget {
  const BindingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bindings = ref.watch(identityBindingsProvider);
    final settings = ref.watch(publicSettingsProvider).value;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('bindings.title'))),
      body: AsyncValueView(
        value: bindings,
        onRetry: () => ref.invalidate(identityBindingsProvider),
        builder: (context, list) {
          // 邮箱始终展示;第三方:已绑定或已开启才展示。
          final visible = list.where((b) {
            if (b.provider == 'email') return true;
            return b.bound || _enabled(b.provider, settings);
          }).toList();
          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  context.tr('bindings.oauthBindHint'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              for (final b in visible)
                _BindingTile(
                  binding: b,
                  enabled: _enabled(b.provider, settings),
                ),
            ],
          );
        },
      ),
    );
  }

  bool _enabled(String provider, PublicSettingsLite? s) {
    if (s == null) return false;
    switch (provider) {
      case 'linuxdo':
        return s.linuxdoOauthEnabled;
      case 'dingtalk':
        return s.dingtalkOauthEnabled;
      case 'oidc':
        return s.oidcOauthEnabled;
      case 'wechat':
        return s.wechatOauthEnabled;
      default:
        return false;
    }
  }
}

String _providerLabel(BuildContext context, String provider) {
  switch (provider) {
    case 'email':
      return context.tr('bindings.providerEmail');
    case 'wechat':
      return context.tr('bindings.providerWechat');
    case 'dingtalk':
      return context.tr('bindings.providerDingtalk');
    case 'linuxdo':
      return 'LinuxDO';
    case 'oidc':
      return 'OIDC';
    default:
      return provider;
  }
}

IconData _providerIcon(String provider) {
  switch (provider) {
    case 'email':
      return Icons.mail_outline;
    case 'wechat':
      return Icons.chat_outlined;
    case 'dingtalk':
      return Icons.business_outlined;
    default:
      return Icons.account_circle_outlined;
  }
}

class _BindingTile extends ConsumerWidget {
  const _BindingTile({required this.binding, required this.enabled});

  final IdentityBinding binding;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final name = _providerLabel(context, binding.provider);
    final isEmail = binding.provider == 'email';
    final canBindNow = !binding.bound && binding.canBind && enabled;

    Widget? trailing;
    if (isEmail) {
      // 邮箱:未绑定可绑定、已绑定可修改(换绑);始终不可解绑。
      trailing = binding.bound
          ? OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36)),
              onPressed: () => _bindEmail(context, ref),
              child: Text(context.tr('bindings.change')),
            )
          : FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 36)),
              onPressed: () => _bindEmail(context, ref),
              child: Text(context.tr('bindings.bind')),
            );
    } else if (binding.bound && binding.canUnbind) {
      trailing = OutlinedButton(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 36),
          foregroundColor: scheme.error,
        ),
        onPressed: () => _unbind(context, ref, name),
        child: Text(context.tr('bindings.unbind')),
      );
    } else if (canBindNow) {
      trailing = FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size(0, 36)),
        onPressed: () => _bindOAuth(context, ref),
        child: Text(context.tr('bindings.bind')),
      );
    }

    return ListTile(
      leading: Icon(_providerIcon(binding.provider)),
      title: Text(name),
      subtitle: Text(
        binding.bound
            ? context.tr('bindings.bound')
            : context.tr('bindings.notBound'),
        style: TextStyle(
          color: binding.bound ? scheme.primary : scheme.onSurfaceVariant,
        ),
      ),
      trailing: trailing,
    );
  }

  Future<void> _unbind(
      BuildContext context, WidgetRef ref, String name) async {
    final ok = await showConfirmDialog(
      context,
      title: context.tr('bindings.unbind'),
      message: context.tr('bindings.unbindConfirm', params: {'name': name}),
      confirmLabel: context.tr('bindings.unbind'),
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(profileApiProvider).unbindIdentity(binding.provider);
      ref.invalidate(identityBindingsProvider);
      await ref.read(sessionControllerProvider.notifier).refreshUser();
      if (context.mounted) {
        showAppToast(context, context.tr('bindings.unbound'));
      }
    } catch (_) {
      if (context.mounted) {
        showAppToast(context, context.tr('bindings.bindFailed'), error: true);
      }
    }
  }

  Future<void> _bindEmail(BuildContext context, WidgetRef ref) async {
    final done = await showDialog<bool>(
      context: context,
      builder: (_) => const _BindEmailDialog(),
    );
    if (done == true) {
      ref.invalidate(identityBindingsProvider);
      await ref.read(sessionControllerProvider.notifier).refreshUser();
    }
  }

  /// 第三方绑定:对齐 web —— 先写入「绑定当前用户」临时令牌,再打开 bind/start 链接。
  Future<void> _bindOAuth(BuildContext context, WidgetRef ref) async {
    final server = ref.read(activeServerProvider);
    final useExternal = ref.read(externalBrowserProvider);
    try {
      await ref.read(profileApiProvider).prepareOAuthBindToken();
    } catch (_) {
      // 令牌准备失败不阻断,后端会在浏览器内要求登录
    }
    final origin = server.baseUrl.endsWith('/')
        ? server.baseUrl.substring(0, server.baseUrl.length - 1)
        : server.baseUrl;
    final uri = Uri.parse(
      '$origin/api/v1/auth/oauth/${binding.provider}/bind/start'
      '?redirect=/profile&intent=bind_current_user',
    );
    if (context.mounted) {
      showAppToast(context, context.tr('bindings.oauthOpening'));
    }
    final ok = await launchUrl(
      uri,
      mode: useExternal
          ? LaunchMode.externalApplication
          : LaunchMode.inAppBrowserView,
    );
    if (!ok && context.mounted) {
      showAppToast(context, context.tr('bindings.bindFailed'), error: true);
    }
  }
}

/// 邮箱绑定弹窗:邮箱 + 验证码(发送+倒计时)+ 账号密码。
class _BindEmailDialog extends ConsumerStatefulWidget {
  const _BindEmailDialog();

  @override
  ConsumerState<_BindEmailDialog> createState() => _BindEmailDialogState();
}

class _BindEmailDialogState extends ConsumerState<_BindEmailDialog> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;
  int _resendIn = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = context.tr('auth.emailInvalid'));
      return;
    }
    setState(() => _error = null);
    try {
      await ref.read(profileApiProvider).sendEmailBindingCode(email);
      if (!mounted) return;
      showAppToast(context, context.tr('auth.verifyCodeSent'));
      setState(() => _resendIn = 60);
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
    } catch (_) {
      if (mounted) setState(() => _error = context.tr('common.unknownError'));
    }
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final code = _code.text.trim();
    final password = _password.text;
    if (!email.contains('@')) {
      setState(() => _error = context.tr('auth.emailInvalid'));
      return;
    }
    if (code.isEmpty) {
      setState(() => _error = context.tr('auth.verifyCodeRequired'));
      return;
    }
    if (password.length < 6) {
      setState(() => _error = context.tr('auth.passwordTooShort'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(profileApiProvider).bindEmail(
            email: email,
            verifyCode: code,
            password: password,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = context.tr('bindings.bindFailed');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr('bindings.bindEmail')),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr('bindings.bindEmailHint')),
              const SizedBox(height: 16),
              TextField(
                controller: _email,
                enabled: !_busy,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: context.tr('auth.email'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _code,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.tr('auth.verifyCode'),
                  border: const OutlineInputBorder(),
                  suffixIcon: TextButton(
                    onPressed: (_busy || _resendIn > 0) ? null : _sendCode,
                    child: Text(_resendIn > 0
                        ? context.tr('auth.resendIn',
                            params: {'seconds': '$_resendIn'})
                        : context.tr('auth.sendCode')),
                  ),
                  suffixIconConstraints:
                      const BoxConstraints(minWidth: 0, minHeight: 0),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                enabled: !_busy,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: context.tr('bindings.password'),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(context.tr('bindings.bind')),
        ),
        OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(context.tr('common.cancel')),
        ),
      ],
    );
  }
}
