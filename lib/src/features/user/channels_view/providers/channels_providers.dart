import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client_provider.dart';
import '../data/channels_api.dart';

final channelsApiProvider = Provider<ChannelsApi>(
  (ref) => ChannelsApi(ref.watch(apiClientProvider)),
);

/// 可用渠道列表。
final availableChannelsProvider =
    FutureProvider.autoDispose<List<AvailableChannel>>(
  (ref) => ref.watch(channelsApiProvider).available(),
);

/// 渠道监控列表。
final channelMonitorsProvider = FutureProvider.autoDispose<List<MonitorView>>(
  (ref) => ref.watch(channelsApiProvider).monitors(),
);

/// 单个监控的状态详情。
final monitorStatusProvider =
    FutureProvider.autoDispose.family<MonitorDetail, int>(
  (ref, id) => ref.watch(channelsApiProvider).monitorStatus(id),
);
