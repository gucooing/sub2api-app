import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/update/update_service.dart';
import '../../i18n/app_localizations.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/markdown_text.dart';

/// 执行一次更新检查。
/// [silent] 为 true 时仅在有更新时弹窗(启动自动检查用);
/// 为 false 时还会提示「已是最新」或错误(设置里手动检查用)。
Future<void> runUpdateCheck(
  BuildContext context,
  WidgetRef ref, {
  bool silent = false,
}) async {
  UpdateCheckResult result;
  try {
    result = await ref.read(updateServiceProvider).check();
  } catch (_) {
    if (!silent && context.mounted) {
      showAppToast(context, context.tr('update.checkFailed'), error: true);
    }
    return;
  }
  if (!context.mounted) return;
  if (result.hasUpdate && result.latest != null) {
    await _showUpdateDialog(context, result.latest!);
  } else if (!silent) {
    showAppToast(context, context.tr('update.upToDate'));
  }
}

Future<void> _showUpdateDialog(BuildContext context, AppRelease release) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.tr('update.found', params: {'version': release.version})),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 360),
        child: SingleChildScrollView(
          child: release.notes.trim().isEmpty
              ? Text(context.tr('update.foundHint'))
              : MarkdownText(release.notes),
        ),
      ),
      actions: [
        FilledButton.icon(
          onPressed: () async {
            final asset = release.assetForCurrentPlatform();
            final url = asset?.downloadUrl ?? release.htmlUrl;
            final uri = Uri.tryParse(url);
            if (uri != null) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
            if (context.mounted) Navigator.of(context).pop();
          },
          icon: const Icon(Icons.download_outlined),
          label: Text(context.tr('update.download')),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('update.later')),
        ),
      ],
    ),
  );
}
