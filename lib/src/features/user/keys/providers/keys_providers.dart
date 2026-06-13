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

/// 列表中各密钥的今日/累计消耗(随列表一起加载;失败不影响列表展示)。
final keysUsageProvider =
    FutureProvider.autoDispose<Map<int, KeyUsageStat>>((ref) async {
  final keys = await ref.watch(keysListProvider.future);
  final ids = keys.map((k) => k.id).toList();
  return ref.watch(keysApiProvider).usageStats(ids);
});

/// 单个密钥的每日用量明细(详情页趋势图)。
final keyDailyUsageProvider = FutureProvider.autoDispose
    .family<List<ApiKeyDailyPoint>, int>(
  (ref, id) => ref.watch(keysApiProvider).dailyUsage(id),
);

/// 创建/编辑表单的可选分组。
final availableGroupsProvider =
    FutureProvider.autoDispose<List<AvailableGroup>>(
  (ref) => ref.watch(keysApiProvider).availableGroups(),
);
