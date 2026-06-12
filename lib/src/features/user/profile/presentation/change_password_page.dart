import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/session/session_controller.dart';
import '../../../../i18n/app_localizations.dart';
import '../providers/profile_providers.dart';

/// 修改密码页面。
class ChangePasswordPage extends ConsumerStatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  ConsumerState<ChangePasswordPage> createState() =>
      _ChangePasswordPageState();
}

class _ChangePasswordPageState extends ConsumerState<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _oldPasswordVisible = false;
  bool _newPasswordVisible = false;
  bool _confirmPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final api = ref.read(profileApiProvider);
      await api.changePassword(
        oldPassword: _oldPasswordController.text,
        newPassword: _newPasswordController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('profile.passwordChanged'))),
      );
      // 修改密码成功后自动登出
      ref.read(sessionControllerProvider.notifier).logout();
      context.go('/login');
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      final message = error is ApiException
          ? error.serverMessage ?? context.tr('common.unknownError')
          : context.tr('common.unknownError');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('profile.changePassword'))),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              context.tr('profile.changePasswordHint'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _oldPasswordController,
              decoration: InputDecoration(
                labelText: context.tr('profile.oldPassword'),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _oldPasswordVisible
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => _oldPasswordVisible = !_oldPasswordVisible),
                ),
                border: const OutlineInputBorder(),
              ),
              obscureText: !_oldPasswordVisible,
              enabled: !_isLoading,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return context.tr('auth.passwordRequired');
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _newPasswordController,
              decoration: InputDecoration(
                labelText: context.tr('profile.newPassword'),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _newPasswordVisible
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => _newPasswordVisible = !_newPasswordVisible),
                ),
                border: const OutlineInputBorder(),
              ),
              obscureText: !_newPasswordVisible,
              enabled: !_isLoading,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return context.tr('auth.passwordRequired');
                }
                if (value.length < 6) {
                  return context.tr('auth.passwordTooShort');
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmPasswordController,
              decoration: InputDecoration(
                labelText: context.tr('auth.passwordConfirm'),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _confirmPasswordVisible
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () => setState(
                      () => _confirmPasswordVisible = !_confirmPasswordVisible),
                ),
                border: const OutlineInputBorder(),
              ),
              obscureText: !_confirmPasswordVisible,
              enabled: !_isLoading,
              validator: (value) {
                if (value != _newPasswordController.text) {
                  return context.tr('auth.passwordMismatch');
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isLoading ? null : _submit,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(context.tr('common.confirm')),
            ),
          ],
        ),
      ),
    );
  }
}
