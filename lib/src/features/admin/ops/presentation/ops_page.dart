import 'package:flutter/material.dart';

import '../../../../i18n/app_localizations.dart';
import 'ops_alerts_tab.dart';
import 'ops_errors_tab.dart';
import 'ops_overview_tab.dart';
import 'ops_system_logs_tab.dart';

/// 运维管理(对照 web OpsDashboard,移动端聚焦总览/错误/系统日志/告警)。
class OpsPage extends StatelessWidget {
  const OpsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.tr('adminOps.title')),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: context.tr('adminOps.tabOverview')),
              Tab(text: context.tr('adminOps.tabErrors')),
              Tab(text: context.tr('adminOps.tabSystemLogs')),
              Tab(text: context.tr('adminOps.tabAlerts')),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            OpsOverviewTab(),
            OpsErrorsTab(),
            OpsSystemLogsTab(),
            OpsAlertsTab(),
          ],
        ),
      ),
    );
  }
}
