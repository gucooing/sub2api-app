import 'package:flutter/material.dart';

import '../../../i18n/app_localizations.dart';

/// 管理端分支 tab 的占位内容(无 Scaffold,由 AdminShell 提供外壳)。
/// 模块实装后替换为真实页面。
class AdminTabPlaceholder extends StatelessWidget {
  const AdminTabPlaceholder({super.key, this.hintKey = 'common.comingSoon'});

  final String hintKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.construction_outlined, size: 56, color: scheme.outline),
          const SizedBox(height: 12),
          Text(
            context.tr(hintKey),
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
