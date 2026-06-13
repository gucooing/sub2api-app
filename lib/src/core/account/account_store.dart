import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/prefs_store.dart';
import 'account_profile.dart';

/// 账号列表状态。
@immutable
class AccountState {
  const AccountState({required this.accounts, this.activeId});

  final List<AccountProfile> accounts;

  /// 当前激活账号 id;null 表示无已登录账号(未登录)。
  final String? activeId;

  AccountProfile? get active {
    if (activeId == null) return null;
    for (final a in accounts) {
      if (a.id == activeId) return a;
    }
    return null;
  }
}

/// 多账号管理:增改(upsert)、激活切换、删除,持久化到 SharedPreferences。
///
/// 令牌按账号 id 存于 SecureStore;此处只存账号档案与激活项。
class AccountStore extends Notifier<AccountState> {
  @override
  AccountState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final raw = prefs.getString(PrefKeys.accounts);
    var accounts = <AccountProfile>[];
    if (raw != null && raw.isNotEmpty) {
      try {
        accounts = (jsonDecode(raw) as List)
            .whereType<Map>()
            .map((e) => AccountProfile.fromJson(e.cast<String, dynamic>()))
            .toList();
      } catch (_) {
        accounts = [];
      }
    }
    var activeId = prefs.getString(PrefKeys.activeAccountId);
    if (activeId != null && !accounts.any((a) => a.id == activeId)) {
      activeId = accounts.isNotEmpty ? accounts.first.id : null;
    }
    return AccountState(accounts: accounts, activeId: activeId);
  }

  Future<void> _persist(AccountState next) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(
      PrefKeys.accounts,
      jsonEncode(next.accounts.map((a) => a.toJson()).toList()),
    );
    if (next.activeId == null) {
      await prefs.remove(PrefKeys.activeAccountId);
    } else {
      await prefs.setString(PrefKeys.activeAccountId, next.activeId!);
    }
    state = next;
  }

  /// 新增或更新账号(按 id 去重);不改变激活项。返回账号 id。
  Future<String> upsert(AccountProfile account) async {
    final existing = state.accounts.indexWhere((a) => a.id == account.id);
    final accounts = [...state.accounts];
    if (existing >= 0) {
      accounts[existing] = account;
    } else {
      accounts.add(account);
    }
    await _persist(AccountState(accounts: accounts, activeId: state.activeId));
    return account.id;
  }

  /// 切换激活账号(不存在或已是激活则忽略)。
  Future<void> setActive(String id) async {
    if (id == state.activeId || !state.accounts.any((a) => a.id == id)) return;
    await _persist(AccountState(accounts: state.accounts, activeId: id));
  }

  /// 删除账号;若删的是激活账号,自动切到列表中下一个(没有则置空)。
  Future<void> remove(String id) async {
    final accounts = state.accounts.where((a) => a.id != id).toList();
    var activeId = state.activeId;
    if (activeId == id) {
      activeId = accounts.isNotEmpty ? accounts.first.id : null;
    }
    await _persist(AccountState(accounts: accounts, activeId: activeId));
  }
}

final accountStoreProvider =
    NotifierProvider<AccountStore, AccountState>(AccountStore.new);

/// 当前激活账号(细粒度依赖)。
final activeAccountProvider = Provider<AccountProfile?>(
  (ref) => ref.watch(accountStoreProvider).active,
);
