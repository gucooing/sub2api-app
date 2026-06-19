import 'package:flutter/material.dart';

import '../../../../i18n/app_localizations.dart';
import '../providers/admin_affiliates_providers.dart';
import 'affiliate_records_tab.dart';

/// 邀请返利管理(对照 web 侧栏「邀请/返利/转账记录」三页),移动端合为 Tab。
class AdminAffiliatesPage extends StatelessWidget {
  const AdminAffiliatesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.tr('adminAffiliates.title')),
          bottom: TabBar(
            tabs: [
              Tab(text: context.tr('adminAffiliates.tabInvites')),
              Tab(text: context.tr('adminAffiliates.tabRebates')),
              Tab(text: context.tr('adminAffiliates.tabTransfers')),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            AffiliateRecordsTab(type: AffiliateRecordType.invites),
            AffiliateRecordsTab(type: AffiliateRecordType.rebates),
            AffiliateRecordsTab(type: AffiliateRecordType.transfers),
          ],
        ),
      ),
    );
  }
}
