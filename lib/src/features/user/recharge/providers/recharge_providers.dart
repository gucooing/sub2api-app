import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client_provider.dart';
import '../data/recharge_api.dart';

final rechargeApiProvider = Provider<RechargeApi>(
  (ref) => RechargeApi(ref.watch(apiClientProvider)),
);

/// 充值页聚合信息(可用支付方式/限额/套餐)。
final checkoutInfoProvider = FutureProvider.autoDispose<CheckoutInfo>(
  (ref) => ref.watch(rechargeApiProvider).checkoutInfo(),
);

/// 我的充值订单历史。
final myOrdersProvider = FutureProvider.autoDispose<List<PaymentOrder>>(
  (ref) => ref.watch(rechargeApiProvider).myOrders(),
);
