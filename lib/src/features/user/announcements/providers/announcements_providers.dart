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

/// 未读公告列表提供者。
final unreadAnnouncementsProvider =
    FutureProvider.autoDispose<List<UserAnnouncement>>((ref) async {
  final api = ref.watch(announcementsApiProvider);
  return await api.list(unreadOnly: true);
});

/// 未读公告数量。
final unreadAnnouncementsCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final unread = await ref.watch(unreadAnnouncementsProvider.future);
  return unread.length;
});
