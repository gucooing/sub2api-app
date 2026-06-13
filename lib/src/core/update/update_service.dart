import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 编译时注入的构建时间(CI:`--dart-define=APP_BUILD_TIME=<ISO8601>`);本地为空。
const String kBuildTime =
    String.fromEnvironment('APP_BUILD_TIME', defaultValue: '');

/// 发布仓库与接口。
const String kReleasesPageUrl =
    'https://github.com/gucooing/sub2api-app/releases';
const String _latestApi =
    'https://api.github.com/repos/gucooing/sub2api-app/releases/latest';

/// Release 中的一个下载资产。
@immutable
class ReleaseAsset {
  const ReleaseAsset({required this.name, required this.downloadUrl});

  final String name;
  final String downloadUrl;

  factory ReleaseAsset.fromJson(Map<String, dynamic> json) => ReleaseAsset(
        name: json['name'] as String? ?? '',
        downloadUrl: json['browser_download_url'] as String? ?? '',
      );
}

/// 一个 Release。
@immutable
class AppRelease {
  const AppRelease({
    required this.version,
    required this.htmlUrl,
    required this.notes,
    required this.assets,
  });

  /// 去掉前缀 v 的版本号。
  final String version;
  final String htmlUrl;
  final String notes;
  final List<ReleaseAsset> assets;

  factory AppRelease.fromJson(Map<String, dynamic> json) {
    final tag = (json['tag_name'] as String? ?? '').trim();
    final assetsRaw = json['assets'];
    return AppRelease(
      version: tag.startsWith('v') ? tag.substring(1) : tag,
      htmlUrl: json['html_url'] as String? ?? kReleasesPageUrl,
      notes: json['body'] as String? ?? '',
      assets: assetsRaw is List
          ? assetsRaw
              .whereType<Map>()
              .map((e) => ReleaseAsset.fromJson(e.cast<String, dynamic>()))
              .toList()
          : const [],
    );
  }

  /// 当前平台建议下载的资产;选不到返回 null(回退打开 [htmlUrl])。
  ReleaseAsset? assetForCurrentPlatform() {
    bool has(ReleaseAsset a, String kw) =>
        a.name.toLowerCase().contains(kw);
    ReleaseAsset? pick(bool Function(ReleaseAsset) test) {
      for (final a in assets) {
        if (test(a)) return a;
      }
      return null;
    }

    if (Platform.isAndroid) {
      return pick((a) => has(a, 'android') && has(a, 'arm64-v8a')) ??
          pick((a) => has(a, 'android') && has(a, 'armeabi')) ??
          pick((a) => has(a, '.apk'));
    }
    if (Platform.isWindows) {
      return pick((a) => has(a, 'windows') && has(a, 'setup')) ??
          pick((a) => has(a, 'windows'));
    }
    if (Platform.isLinux) {
      return pick((a) => has(a, '.appimage')) ??
          pick((a) => has(a, '.deb')) ??
          pick((a) => has(a, 'linux'));
    }
    if (Platform.isMacOS) {
      return pick((a) => has(a, '.dmg')) ?? pick((a) => has(a, 'macos'));
    }
    if (Platform.isIOS) {
      return pick((a) => has(a, '.ipa'));
    }
    return null;
  }
}

/// 更新检查结果。
@immutable
class UpdateCheckResult {
  const UpdateCheckResult({
    required this.currentVersion,
    required this.latest,
    required this.hasUpdate,
  });

  final String currentVersion;
  final AppRelease? latest;
  final bool hasUpdate;
}

/// 更新检查服务:对比当前版本与 GitHub 最新 Release。
class UpdateService {
  UpdateService([Dio? dio]) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<String> currentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  Future<UpdateCheckResult> check() async {
    final current = await currentVersion();
    AppRelease? latest;
    try {
      final res = await _dio.get<dynamic>(
        _latestApi,
        options: Options(
          headers: {'Accept': 'application/vnd.github+json'},
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );
      if (res.data is Map) {
        latest = AppRelease.fromJson((res.data as Map).cast<String, dynamic>());
      }
    } catch (_) {
      latest = null;
    }
    final hasUpdate = latest != null &&
        latest.version.isNotEmpty &&
        compareVersions(latest.version, current) > 0;
    return UpdateCheckResult(
      currentVersion: current,
      latest: latest,
      hasUpdate: hasUpdate,
    );
  }

  /// 语义化版本比较:a>b 返回正,a<b 返回负,相等返回 0。仅比较前三段数字。
  static int compareVersions(String a, String b) {
    List<int> parse(String s) => s
        .split('.')
        .map((p) =>
            int.tryParse(RegExp(r'\d+').firstMatch(p)?.group(0) ?? '0') ?? 0)
        .toList();
    final pa = parse(a);
    final pb = parse(b);
    for (var i = 0; i < 3; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x - y;
    }
    return 0;
  }
}

final updateServiceProvider = Provider<UpdateService>((ref) => UpdateService());

/// 当前应用版本号(展示用)。
final appVersionProvider = FutureProvider<String>(
  (ref) => ref.watch(updateServiceProvider).currentVersion(),
);

/// 更新检查(手动刷新用 `ref.invalidate`)。
final updateCheckProvider = FutureProvider.autoDispose<UpdateCheckResult>(
  (ref) => ref.watch(updateServiceProvider).check(),
);
