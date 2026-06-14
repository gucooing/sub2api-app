import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client_provider.dart';
import '../data/admin_settings_api.dart';

final adminSettingsApiProvider = Provider<AdminSettingsApi>(
  (ref) => AdminSettingsApi(ref.watch(apiClientProvider)),
);

/// 服务端系统设置原始字段;保存后用 `ref.invalidate` 重新拉取。
final adminSettingsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  return ref.watch(adminSettingsApiProvider).getRaw();
});
