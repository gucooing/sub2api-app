import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'src/core/logging/app_logger.dart';
import 'src/core/storage/prefs_store.dart';
import 'src/i18n/language_pack_loader.dart';
import 'src/i18n/language_pack_registry.dart';
import 'src/i18n/locale_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 日志:启动期装配 + 接管未捕获异常(写入前脱敏)。
  await AppLogger.instance.init();
  final priorOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    AppLogger.instance.flutterError(details);
    priorOnError?.call(details);
  };
  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    AppLogger.instance.error('未捕获异常', error: error, stack: stack);
    return false;
  };

  // 启动期同步装配:本地配置 + 语言包(内置 + 外置),
  // 使语言/主题状态在首帧即就绪,避免闪烁。
  final prefs = await SharedPreferences.getInstance();

  final loader = LanguagePackLoader();
  final registry = LanguagePackRegistry();
  registry.replaceAll(await loader.loadAll(), fallbackTag: loader.fallbackTag);

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        languagePackRegistryProvider.overrideWithValue(registry),
        languagePackLoaderProvider.overrideWithValue(loader),
      ],
      child: const Sub2apiApp(),
    ),
  );
}
