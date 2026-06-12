import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client_provider.dart';
import '../data/announcements_api.dart';

final announcementsApiProvider = Provider<AnnouncementsApi>((ref) {
  final client = ref.watch(apiClientProvider);
  return AnnouncementsApi(client);
});

/// 公告列表提供者。
final announcementsListProvider =
    FutureProvider.autoDispose<List<UserAnnouncement>>((ref) async {
  final api = ref.watch(announcementsApiProvider);
  return await api.list();
});
