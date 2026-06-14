import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../storage/prefs_store.dart';
import 'server_profile.dart';

/// 服务器列表状态。
@immutable
class ServerState {
  const ServerState({required this.servers, required this.activeId});

  final List<ServerProfile> servers;
  final String activeId;

  ServerProfile get active =>
      servers.firstWhere((s) => s.id == activeId, orElse: () => servers.first);
}

/// 多后端管理:列表增删改、激活切换,持久化到 SharedPreferences。
/// 首次启动注入内置默认服务器(官方 ai.alsl.xyz)。
class ServerStore extends Notifier<ServerState> {
  static const ServerProfile _builtIn = ServerProfile(
    id: 'default',
    name: 'Codex Api',
    baseUrl: AppConfig.defaultBaseUrl,
    builtIn: true,
  );

  @override
  ServerState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final raw = prefs.getString(PrefKeys.servers);
    var servers = <ServerProfile>[];
    if (raw != null && raw.isNotEmpty) {
      try {
        servers = (jsonDecode(raw) as List)
            .whereType<Map>()
            .map((e) => ServerProfile.fromJson(e.cast<String, dynamic>()))
            .toList();
      } catch (_) {
        servers = [];
      }
    }
    // 内置项始终存在且置顶。
    servers.removeWhere((s) => s.id == _builtIn.id);
    servers.insert(0, _builtIn);

    var activeId = prefs.getString(PrefKeys.activeServerId) ?? _builtIn.id;
    if (!servers.any((s) => s.id == activeId)) activeId = _builtIn.id;
    return ServerState(servers: servers, activeId: activeId);
  }

  Future<void> _persist(ServerState next) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(
      PrefKeys.servers,
      jsonEncode(next.servers.map((s) => s.toJson()).toList()),
    );
    await prefs.setString(PrefKeys.activeServerId, next.activeId);
    state = next;
  }

  /// 新增服务器并返回 ID;baseUrl 不合法返回 null。
  Future<String?> add(String name, String baseUrl) async {
    final normalized = ServerProfile.normalizeBaseUrl(baseUrl);
    if (normalized == null) return null;
    final id = 'srv_${DateTime.now().millisecondsSinceEpoch}';
    final profile = ServerProfile(
      id: id,
      name: name.trim().isEmpty ? normalized : name.trim(),
      baseUrl: normalized,
    );
    await _persist(ServerState(
      servers: [...state.servers, profile],
      activeId: state.activeId,
    ));
    return id;
  }

  /// 编辑名称/地址(内置项只允许改名)。baseUrl 不合法返回 false。
  Future<bool> update(String id, {String? name, String? baseUrl}) async {
    String? normalized;
    if (baseUrl != null) {
      normalized = ServerProfile.normalizeBaseUrl(baseUrl);
      if (normalized == null) return false;
    }
    final servers = state.servers.map((s) {
      if (s.id != id) return s;
      return s.copyWith(
        name: name,
        baseUrl: s.builtIn ? null : normalized,
      );
    }).toList();
    await _persist(ServerState(servers: servers, activeId: state.activeId));
    return true;
  }

  /// 删除(内置项与当前激活项不可删)。
  Future<bool> remove(String id) async {
    final target = state.servers.where((s) => s.id == id).firstOrNull;
    if (target == null || target.builtIn || id == state.activeId) return false;
    await _persist(ServerState(
      servers: state.servers.where((s) => s.id != id).toList(),
      activeId: state.activeId,
    ));
    return true;
  }

  /// 切换激活服务器。会话层监听此变化做相应的恢复/登出。
  Future<void> setActive(String id) async {
    if (!state.servers.any((s) => s.id == id) || id == state.activeId) return;
    await _persist(ServerState(servers: state.servers, activeId: id));
  }
}

final serverStoreProvider =
    NotifierProvider<ServerStore, ServerState>(ServerStore.new);

/// 当前激活的服务器(细粒度依赖,减少无关重建)。
final activeServerProvider = Provider<ServerProfile>(
  (ref) => ref.watch(serverStoreProvider).active,
);
