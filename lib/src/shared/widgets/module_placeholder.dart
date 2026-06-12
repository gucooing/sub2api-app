import 'package:flutter/material.dart';

import '../../i18n/app_localizations.dart';

/// 规划中模块的统一占位页。[titleKey] 为 AppBar 标题的 i18n 键。
class ModulePlaceholderScreen extends StatelessWidget {
  const ModulePlaceholderScreen({super.key, required this.titleKey});

  final String titleKey;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr(titleKey))),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.construction_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              context.tr('common.comingSoon'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
