import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client_provider.dart';
import '../data/profile_api.dart';

final profileApiProvider = Provider<ProfileApi>((ref) {
  final client = ref.watch(apiClientProvider);
  return ProfileApi(client);
});

/// TOTP 状态提供者。
final totpStatusProvider = FutureProvider.autoDispose<TotpStatus>((ref) async {
  final api = ref.watch(profileApiProvider);
  return await api.getTotpStatus();
});

/// 登录方式绑定状态。
final identityBindingsProvider =
    FutureProvider.autoDispose<List<IdentityBinding>>((ref) async {
  final api = ref.watch(profileApiProvider);
  return await api.identityBindings();
});
