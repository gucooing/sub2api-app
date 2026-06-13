import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/session/auth_models.dart';
import '../../../../core/session/session_controller.dart';
import '../../../../i18n/app_localizations.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../data/profile_api.dart';
import '../providers/profile_providers.dart';

/// 绑定设置:查询并修改登录方式绑定(邮箱可在应用内绑定;第三方登录可解绑,
/// 绑定请前往网页端)。
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
          final visible = list
              .where((b) => b.bound || _enabled(b.provider, settings))
              .toList();
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
              for (final b in visible) _BindingTile(binding: b),
            ],
          );
        },
      ),
    );
  }

  bool _enabled(String provider, PublicSettingsLite? s) {
    if (s == null) return provider == 'email';
    switch (provider) {
      case 'email':
        return true;
      case 'linuxdo':
        return s.linuxdoOauthEnabled;
      case 'oidc':
        return s.oidcOauthEnabled;
      case 'github':
        return s.githubOauthEnabled;
      case 'google':
        return s.googleOauthEnabled;
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
    case 'linuxdo':
      return 'LinuxDO';
    case 'oidc':
      return 'OIDC';
    case 'github':
      return 'GitHub';
    case 'google':
      return 'Google';
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
    default:
      return Icons.account_circle_outlined;
  }
}

class _BindingTile extends ConsumerWidget {
  const _BindingTile({required this.binding});

  final IdentityBinding binding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final name = _providerLabel(context, binding.provider);
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
      trailing: binding.bound
          ? OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 36),
                foregroundColor: scheme.error,
              ),
              onPressed: () => _unbind(context, ref, name),
              child: Text(context.tr('bindings.unbind')),
            )
          : (binding.provider == 'email'
              ? FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 36)),
                  onPressed: () => _bindEmail(context, ref),
                  child: Text(context.tr('bindings.bind')),
                )
              : null),
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
      if (context.mounted) showAppToast(context, context.tr('bindings.unbound'));
    } catch (_) {
      if (context.mounted) {
        showAppToast(context, context.tr('common.unknownError'), error: true);
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
}

class _BindEmailDialog extends ConsumerStatefulWidget {
  const _BindEmailDialog();

  @override
  ConsumerState<_BindEmailDialog> createState() => _BindEmailDialogState();
}

class _BindEmailDialogState extends ConsumerState<_BindEmailDialog> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;
  int _resendIn = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _code.dispose();
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
    } catch (e) {
      if (mounted) setState(() => _error = context.tr('common.unknownError'));
    }
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final code = _code.text.trim();
    if (!email.contains('@') || code.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(profileApiProvider).bindEmail(email: email, code: code);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = context.tr('common.unknownError');
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
                  onPressed:
                      (_busy || _resendIn > 0) ? null : _sendCode,
                  child: Text(_resendIn > 0
                      ? context.tr('auth.resendIn',
                          params: {'seconds': '$_resendIn'})
                      : context.tr('auth.sendCode')),
                ),
                suffixIconConstraints:
                    const BoxConstraints(minWidth: 0, minHeight: 0),
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
