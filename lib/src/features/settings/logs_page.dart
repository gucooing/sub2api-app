import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/logging/app_logger.dart';
import '../../i18n/app_localizations.dart';
import '../../shared/format/formatters.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/empty_state.dart';

/// 日志页:展示已记录的异常/错误(已脱敏),支持复制导出与清空。
class LogsPage extends StatelessWidget {
  const LogsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logger = AppLogger.instance;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('logs.title')),
        actions: [
          IconButton(
            tooltip: context.tr('logs.copyAll'),
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: () async {
              final text = logger.exportText();
              if (text.trim().isEmpty) {
                showAppToast(context, context.tr('logs.empty'));
                return;
              }
              await Clipboard.setData(ClipboardData(text: text));
              if (context.mounted) {
                showAppToast(context, context.tr('logs.copied'));
              }
            },
          ),
          IconButton(
            tooltip: context.tr('logs.clear'),
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await showConfirmDialog(
                context,
                title: context.tr('logs.clear'),
                message: context.tr('logs.clearConfirm'),
                confirmLabel: context.tr('logs.clear'),
                destructive: true,
              );
              if (ok) await logger.clear();
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: logger,
        builder: (context, _) {
          final entries = logger.entries;
          if (entries.isEmpty) {
            return EmptyState(
              icon: Icons.receipt_long_outlined,
              message: context.tr('logs.empty'),
              hint: context.tr('logs.hint'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: entries.length,
            separatorBuilder: (_, _) => const Divider(height: 16),
            itemBuilder: (context, i) => _LogTile(entry: entries[i]),
          );
        },
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.entry});

  final LogEntry entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (color, label) = switch (entry.level) {
      'error' => (scheme.error, 'ERROR'),
      'warn' => (const Color(0xFFB7791F), 'WARN'),
      _ => (scheme.onSurfaceVariant, 'INFO'),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(label,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: color, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 8),
            Text(
              formatDateTime(entry.time),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SelectableText(
          entry.message,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(fontFamily: 'monospace'),
        ),
      ],
    );
  }
}
