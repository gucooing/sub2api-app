import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client_provider.dart';
import '../data/admin_settings_api.dart';

final adminSettingsApiProvider = Provider<AdminSettingsApi>(
  (ref) => AdminSettingsApi(ref.watch(apiClientProvider)),
);

/// 服务端系统设置;保存后用 `ref.invalidate` 重新拉取。
final adminSettingsProvider = FutureProvider.autoDispose<AdminSettings>((ref) {
  return ref.watch(adminSettingsApiProvider).get();
});
