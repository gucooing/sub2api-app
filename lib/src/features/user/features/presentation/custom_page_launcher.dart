import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/preferences/external_browser_controller.dart';
import '../../../../core/server/server_store.dart';
import '../../../../core/session/auth_models.dart';
import '../../../../core/session/session_controller.dart';
import '../../../../core/storage/secure_store.dart';
import '../../../../i18n/app_localizations.dart';

/// 打开一个自定义页面。
///
/// 与 Web 端 `buildEmbeddedUrl` 一致,在 URL 上附带 `user_id/token/theme/lang/ui_mode`,
/// 让目标页面免二次登录。默认走应用内浏览器(携带登录态最稳妥),
/// 用户在设置里开启「使用外置浏览器」后改用系统浏览器。
Future<void> openCustomPage(
  BuildContext context,
  WidgetRef ref,
  CustomMenuItem item,
) async {
  final server = ref.read(activeServerProvider);
  final origin = server.baseUrl;
  final userId = ref.read(sessionControllerProvider).user?.id;
  final token = await ref.read(secureStoreProvider).readAccessToken(server.id);
  final useExternal = ref.read(externalBrowserProvider);

  if (!context.mounted) return;

  // markdown 内容页没有独立外链,交给 Web 的 /custom/{id} 渲染;
  // 外链项直接打开其 url。
  final base = item.isMarkdown
      ? '${_trimTrailingSlash(origin)}/custom/${item.id}'
      : item.url;

  final theme =
      Theme.of(context).brightness == Brightness.dark ? 'dark' : 'light';
  final lang = Localizations.localeOf(context).toLanguageTag();

  final uri = _buildEmbeddedUri(
    base,
    userId: userId,
    token: token,
    theme: theme,
    lang: lang,
  );

  final ok = uri != null &&
      await launchUrl(
        uri,
        mode: useExternal
            ? LaunchMode.externalApplication
            : LaunchMode.inAppBrowserView,
      );

  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr('features.openFailed'))),
    );
  }
}

/// 在 [base] 上叠加嵌入式参数;非 http(s) 返回 null(避免误打开 md: 等伪协议)。
Uri? _buildEmbeddedUri(
  String base, {
  required int? userId,
  required String? token,
  required String theme,
  required String lang,
}) {
  final parsed = Uri.tryParse(base);
  if (parsed == null || !(parsed.isScheme('http') || parsed.isScheme('https'))) {
    return null;
  }
  final params = Map<String, String>.from(parsed.queryParameters)
    ..['theme'] = theme
    ..['lang'] = lang
    ..['ui_mode'] = 'embedded';
  if (userId != null) params['user_id'] = userId.toString();
  if (token != null && token.isNotEmpty) params['token'] = token;
  return parsed.replace(queryParameters: params);
}

String _trimTrailingSlash(String s) =>
    s.endsWith('/') ? s.substring(0, s.length - 1) : s;
