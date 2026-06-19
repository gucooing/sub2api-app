import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../i18n/app_localizations.dart';
import 'risk_logs_tab.dart';
import 'risk_status_tab.dart';

/// 风控(内容审核)管理:状态 / 日志 + 配置入口(对照 web RiskControlView)。
class RiskControlPage extends StatelessWidget {
  const RiskControlPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.tr('adminRisk.title')),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: context.tr('adminRisk.configTitle'),
              onPressed: () => context.push('/admin/risk-control/config'),
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: context.tr('adminRisk.tabStatus')),
              Tab(text: context.tr('adminRisk.tabLogs')),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            RiskStatusTab(),
            RiskLogsTab(),
          ],
        ),
      ),
    );
  }
}
