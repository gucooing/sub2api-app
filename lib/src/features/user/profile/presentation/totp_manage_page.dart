import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../i18n/app_localizations.dart';
import '../data/profile_api.dart';
import '../providers/profile_providers.dart';

/// TOTP 管理页:查看状态,启用或禁用。
class TotpManagePage extends ConsumerWidget {
  const TotpManagePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(totpStatusProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('profile.totp'))),
      body: statusAsync.when(
        data: (status) => status.enabled
            ? _TotpEnabledView(status: status)
            : const _TotpDisabledView(),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline,
                  size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text(
                error is ApiException
                    ? error.serverMessage ?? context.tr('common.unknownError')
                    : context.tr('common.unknownError'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () => ref.invalidate(totpStatusProvider),
                icon: const Icon(Icons.refresh),
                label: Text(context.tr('common.retry')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// TOTP 已启用视图:显示启用时间 + 禁用按钮。
class _TotpEnabledView extends ConsumerWidget {
  const _TotpEnabledView({required this.status});

  final TotpStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    Icons.verified_user,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.tr('profile.totpEnabled'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (status.enabledAt != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      context.tr('profile.totpEnabledAt', params: {
                        'time': _formatDateTime(status.enabledAt!),
                      }),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => _showDisableDialog(context, ref),
            icon: const Icon(Icons.remove_circle_outline),
            label: Text(context.tr('profile.totpDisable')),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDisableDialog(BuildContext context, WidgetRef ref) async {
    final api = ref.read(profileApiProvider);
    String? verificationMethod;

    try {
      verificationMethod = await api.getTotpVerificationMethod();
    } catch (_) {
      verificationMethod = 'password';
    }

    if (!context.mounted) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _DisableTotpDialog(
        verificationMethod: verificationMethod ?? 'password',
      ),
    );

    if (result == true) {
      ref.invalidate(totpStatusProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('profile.totpDisabled'))),
        );
      }
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

/// TOTP 未启用视图:显示说明 + 启用按钮。
class _TotpDisabledView extends ConsumerWidget {
  const _TotpDisabledView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.security,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      Text(
                        context.tr('profile.totpDisabled'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.tr('profile.totpDescription'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _showEnableFlow(context, ref),
            icon: const Icon(Icons.add_circle_outline),
            label: Text(context.tr('profile.totpEnable')),
          ),
        ],
      ),
    );
  }

  Future<void> _showEnableFlow(BuildContext context, WidgetRef ref) async {
    final api = ref.read(profileApiProvider);
    String? verificationMethod;

    try {
      verificationMethod = await api.getTotpVerificationMethod();
    } catch (_) {
      verificationMethod = 'password';
    }

    if (!context.mounted) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _EnableTotpDialog(
        verificationMethod: verificationMethod ?? 'password',
      ),
    );

    if (result == true) {
      ref.invalidate(totpStatusProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('profile.totpEnabled'))),
        );
      }
    }
  }
}

/// 启用 TOTP 对话框。
class _EnableTotpDialog extends ConsumerStatefulWidget {
  const _EnableTotpDialog({required this.verificationMethod});

  final String verificationMethod;

  @override
  ConsumerState<_EnableTotpDialog> createState() => _EnableTotpDialogState();
}

class _EnableTotpDialogState extends ConsumerState<_EnableTotpDialog> {
  final _passwordController = TextEditingController();
  final _emailCodeController = TextEditingController();
  final _totpCodeController = TextEditingController();

  TotpSetupData? _setupData;
  bool _isLoading = false;
  String? _errorMessage;
  int _step = 1; // 1=验证身份, 2=扫码+验证动态码

  @override
  void dispose() {
    _passwordController.dispose();
    _emailCodeController.dispose();
    _totpCodeController.dispose();
    super.dispose();
  }

  Future<void> _sendEmailCode() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(profileApiProvider).sendTotpVerifyCode();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('auth.verifyCodeSent'))),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e is ApiException
            ? e.serverMessage ?? context.tr('common.unknownError')
            : context.tr('common.unknownError');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _initiate() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final api = ref.read(profileApiProvider);
      final data = await api.initiateTotp(
        emailCode: widget.verificationMethod == 'email'
            ? _emailCodeController.text
            : null,
        password: widget.verificationMethod == 'password'
            ? _passwordController.text
            : null,
      );

      setState(() {
        _setupData = data;
        _step = 2;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e is ApiException
            ? e.serverMessage ?? context.tr('common.unknownError')
            : context.tr('common.unknownError');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _enable() async {
    if (_setupData == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final api = ref.read(profileApiProvider);
      await api.enableTotp(
        code: _totpCodeController.text,
        setupToken: _setupData!.setupToken,
      );
      if (mounted) {
        ref.invalidate(totpStatusProvider);
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e is ApiException
            ? e.serverMessage ?? context.tr('common.unknownError')
            : context.tr('common.unknownError');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr('profile.totpEnable')),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: _step == 1 ? _buildStep1() : _buildStep2(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text(context.tr('common.cancel')),
        ),
        FilledButton(
          onPressed: _isLoading ? null : (_step == 1 ? _initiate : _enable),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(context.tr(_step == 1 ? 'common.confirm' : 'profile.totpEnable')),
        ),
      ],
    );
  }

  Widget _buildStep1() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.tr('profile.totpEnableStep1')),
        const SizedBox(height: 16),
        if (widget.verificationMethod == 'email') ...[
          // 注意:AlertDialog 内容受 IntrinsicWidth 约束,这里不能用 Row+Expanded
          // (会导致无界宽度崩溃),改用 TextField 的 suffix 承载「发送验证码」。
          TextField(
            controller: _emailCodeController,
            decoration: InputDecoration(
              labelText: context.tr('auth.verifyCode'),
              border: const OutlineInputBorder(),
              suffixIcon: TextButton(
                onPressed: _isLoading ? null : _sendEmailCode,
                child: Text(context.tr('auth.sendCode')),
              ),
              suffixIconConstraints:
                  const BoxConstraints(minWidth: 0, minHeight: 0),
            ),
            keyboardType: TextInputType.number,
            enabled: !_isLoading,
          ),
        ] else ...[
          TextField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: context.tr('auth.password'),
              border: const OutlineInputBorder(),
            ),
            obscureText: true,
            enabled: !_isLoading,
          ),
        ],
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            _errorMessage!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }

  Widget _buildStep2() {
    if (_setupData == null) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.tr('profile.totpEnableStep2')),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              if (_setupData!.qrCodeUrl.isNotEmpty)
                Image.network(
                  _setupData!.qrCodeUrl,
                  width: 200,
                  height: 200,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      _setupData!.secret,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    onPressed: () {
                      Clipboard.setData(
                          ClipboardData(text: _setupData!.secret));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.tr('common.copied'))),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _totpCodeController,
          decoration: InputDecoration(
            labelText: context.tr('auth.totpCode'),
            border: const OutlineInputBorder(),
            hintText: '123456',
          ),
          keyboardType: TextInputType.number,
          maxLength: 6,
          enabled: !_isLoading,
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            _errorMessage!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }
}

/// 禁用 TOTP 对话框。
class _DisableTotpDialog extends ConsumerStatefulWidget {
  const _DisableTotpDialog({required this.verificationMethod});

  final String verificationMethod;

  @override
  ConsumerState<_DisableTotpDialog> createState() =>
      _DisableTotpDialogState();
}

class _DisableTotpDialogState extends ConsumerState<_DisableTotpDialog> {
  final _passwordController = TextEditingController();
  final _emailCodeController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _emailCodeController.dispose();
    super.dispose();
  }

  Future<void> _sendEmailCode() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(profileApiProvider).sendTotpVerifyCode();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('auth.verifyCodeSent'))),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e is ApiException
            ? e.serverMessage ?? context.tr('common.unknownError')
            : context.tr('common.unknownError');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _disable() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final api = ref.read(profileApiProvider);
      await api.disableTotp(
        emailCode: widget.verificationMethod == 'email'
            ? _emailCodeController.text
            : null,
        password: widget.verificationMethod == 'password'
            ? _passwordController.text
            : null,
      );
      if (mounted) {
        ref.invalidate(totpStatusProvider);
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e is ApiException
            ? e.serverMessage ?? context.tr('common.unknownError')
            : context.tr('common.unknownError');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr('profile.totpDisable')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('profile.totpDisableConfirm')),
          const SizedBox(height: 16),
          if (widget.verificationMethod == 'email') ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _emailCodeController,
                    decoration: InputDecoration(
                      labelText: context.tr('auth.verifyCode'),
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    enabled: !_isLoading,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _isLoading ? null : _sendEmailCode,
                  child: Text(context.tr('auth.sendCode')),
                ),
              ],
            ),
          ] else ...[
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: context.tr('auth.password'),
                border: const OutlineInputBorder(),
              ),
              obscureText: true,
              enabled: !_isLoading,
            ),
          ],
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text(context.tr('common.cancel')),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _disable,
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(context.tr('profile.totpDisable')),
        ),
      ],
    );
  }
}
