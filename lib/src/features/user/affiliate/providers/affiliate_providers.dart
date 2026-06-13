import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client_provider.dart';
import '../data/affiliate_api.dart';

final affiliateApiProvider = Provider<AffiliateApi>(
  (ref) => AffiliateApi(ref.watch(apiClientProvider)),
);

/// 邀请返利详情。
final affiliateDetailProvider = FutureProvider.autoDispose<AffiliateDetail>(
  (ref) => ref.watch(affiliateApiProvider).detail(),
);
