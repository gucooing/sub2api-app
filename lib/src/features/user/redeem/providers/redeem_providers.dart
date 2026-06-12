import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client_provider.dart';
import '../data/redeem_api.dart';

final redeemApiProvider = Provider<RedeemApi>((ref) {
  final client = ref.watch(apiClientProvider);
  return RedeemApi(client);
});

/// 兑换历史列表。
final redeemHistoryProvider =
    FutureProvider.autoDispose<List<RedeemHistoryItem>>((ref) async {
  final api = ref.watch(redeemApiProvider);
  return await api.getHistory();
});
