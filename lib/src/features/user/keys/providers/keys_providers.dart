import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client_provider.dart';
import '../data/keys_api.dart';

final keysApiProvider = Provider<KeysApi>(
  (ref) => KeysApi(ref.watch(apiClientProvider)),
);

/// 密钥列表;增删改后 `ref.invalidate` 刷新。
final keysListProvider = FutureProvider.autoDispose<List<ApiKeyInfo>>(
  (ref) => ref.watch(keysApiProvider).list(),
);

/// 创建/编辑表单的可选分组。
final availableGroupsProvider =
    FutureProvider.autoDispose<List<AvailableGroup>>(
  (ref) => ref.watch(keysApiProvider).availableGroups(),
);
