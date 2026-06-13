import 'package:flutter/material.dart';

import '../../../../i18n/app_localizations.dart';
import '../../../../shared/widgets/responsive.dart';
import 'usage_records_view.dart';

/// 使用记录页面(多维筛选 + 滚动加载,独立入口)。
class UsageLogsPage extends StatelessWidget {
  const UsageLogsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('usageLogs.title'))),
      body: const ResponsiveCenter(
        maxWidth: 840,
        child: UsageRecordsView(),
      ),
    );
  }
}
