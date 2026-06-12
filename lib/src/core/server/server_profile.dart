import 'package:flutter/foundation.dart';

/// 一个 Sub2API 后端服务器配置。
@immutable
class ServerProfile {
  const ServerProfile({
    required this.id,
    required this.name,
    required this.baseUrl,
    this.builtIn = false,
  });

  /// 稳定标识(令牌按此分键存储)。
  final String id;

  /// 显示名,如「官方」。
  final String name;

  /// 服务器 origin,如 `https://ai.alsl.xyz`(不含 /api/v1,结尾无斜杠)。
  final String baseUrl;

  /// 内置项(默认服务器)不可删除。
  final bool builtIn;

  ServerProfile copyWith({String? name, String? baseUrl}) => ServerProfile(
        id: id,
        name: name ?? this.name,
        baseUrl: baseUrl ?? this.baseUrl,
        builtIn: builtIn,
      );

  /// 规范化 origin:去空白、去结尾斜杠。返回 null 表示不合法。
  static String? normalizeBaseUrl(String input) {
    var url = input.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !(uri.scheme == 'https' || uri.scheme == 'http') ||
        uri.host.isEmpty) {
      return null;
    }
    return url;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'base_url': baseUrl,
        'built_in': builtIn,
      };

  factory ServerProfile.fromJson(Map<String, dynamic> json) => ServerProfile(
        id: json['id'] as String,
        name: json['name'] as String,
        baseUrl: json['base_url'] as String,
        builtIn: json['built_in'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) =>
      other is ServerProfile &&
      other.id == id &&
      other.name == name &&
      other.baseUrl == baseUrl &&
      other.builtIn == builtIn;

  @override
  int get hashCode => Object.hash(id, name, baseUrl, builtIn);
}
