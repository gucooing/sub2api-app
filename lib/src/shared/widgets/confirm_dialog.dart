import 'package:flutter/material.dart';

import '../../i18n/app_localizations.dart';

/// 统一的「确认/取消」对话框。
///
/// 全应用的二选一确认弹窗都应走这里,保证取消/确认按钮**等宽等高、样式一致、
/// 处于同一层级**(取消 = 描边按钮,确认 = 实心按钮;[destructive] 时确认转为错误色)。
///
/// 用自绘 [Dialog](宽度有界)而非 [AlertDialog],既能做等宽 [Expanded] 按钮,
/// 又避开 AlertDialog 内部 IntrinsicWidth 对 Expanded 的无界宽度限制。
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  Widget? content,
  String? confirmLabel,
  String? cancelLabel,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final scheme = theme.colorScheme;
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleLarge),
                if (content != null) ...[
                  const SizedBox(height: 16),
                  content,
                ] else if (message != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                        ),
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: Text(cancelLabel ?? ctx.tr('common.cancel')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          backgroundColor: destructive ? scheme.error : null,
                          foregroundColor: destructive ? scheme.onError : null,
                        ),
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: Text(confirmLabel ?? ctx.tr('common.confirm')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  return result ?? false;
}
