import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../i18n/app_localizations.dart';
import 'orders_tab.dart';
import 'payment_dashboard_tab.dart';
import 'plans_tab.dart';

/// 订单与支付管理(对照 web 侧栏「订单/支付看板/订阅计划」三页),移动端合为 Tab。
class AdminOrdersPage extends StatefulWidget {
  const AdminOrdersPage({super.key});

  @override
  State<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends State<AdminOrdersPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this)
    ..addListener(() => setState(() {}));

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('adminOrders.title')),
        bottom: TabBar(
          controller: _tab,
          tabs: [
            Tab(text: context.tr('adminOrders.tabOrders')),
            Tab(text: context.tr('adminOrders.tabDashboard')),
            Tab(text: context.tr('adminOrders.tabPlans')),
          ],
        ),
      ),
      floatingActionButton: _tab.index == 2
          ? FloatingActionButton.extended(
              heroTag: 'fab-admin-plans',
              onPressed: () => context.push('/admin/orders/plans/new'),
              icon: const Icon(Icons.add),
              label: Text(context.tr('adminOrders.createPlan')),
            )
          : null,
      body: TabBarView(
        controller: _tab,
        children: const [
          OrdersTab(),
          PaymentDashboardTab(),
          PlansTab(),
        ],
      ),
    );
  }
}
