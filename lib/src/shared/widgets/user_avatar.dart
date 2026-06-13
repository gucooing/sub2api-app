import 'dart:convert';

import 'package:flutter/widgets.dart';

/// 根据 [url] 返回合适的头像图源:
/// - `data:*;base64,...`(应用内上传头像即此格式)→ [MemoryImage]
/// - `http(s)://...` → [NetworkImage]
/// - 空 / 非法 → null(由调用方回退到首字母占位)
///
/// 注意:[NetworkImage] 不支持 `data:` URI,直接传会导致头像显示失败。
ImageProvider? avatarImageProvider(String? url) {
  if (url == null || url.trim().isEmpty) return null;
  final value = url.trim();
  if (value.startsWith('data:')) {
    final comma = value.indexOf(',');
    if (comma < 0) return null;
    try {
      return MemoryImage(base64Decode(value.substring(comma + 1)));
    } catch (_) {
      return null;
    }
  }
  if (value.startsWith('http://') || value.startsWith('https://')) {
    return NetworkImage(value);
  }
  return null;
}
