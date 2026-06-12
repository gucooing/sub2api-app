import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client_provider.dart';
import '../data/subscriptions_api.dart';

final subscriptionsApiProvider = Provider<SubscriptionsApi>((ref) {
  final client = ref.watch(apiClientProvider);
  return SubscriptionsApi(client);
});

/// 订阅列表提供者。
final subscriptionsListProvider =
    FutureProvider.autoDispose<List<UserSubscription>>((ref) async {
  final api = ref.watch(subscriptionsApiProvider);
  return await api.getMySubscriptions();
});

/// 订阅进度提供者。
final subscriptionsProgressProvider =
    FutureProvider.autoDispose<List<SubscriptionProgress>>((ref) async {
  final api = ref.watch(subscriptionsApiProvider);
  return await api.getProgress();
});
