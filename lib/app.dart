import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/core/config/app_config.dart';
import 'src/core/router/app_router.dart';
import 'src/core/theme/app_theme.dart';
import 'src/core/theme/theme_controller.dart';
import 'src/i18n/app_localizations.dart';
import 'src/i18n/locale_controller.dart';

/// 应用根 Widget。集中装配:路由、明暗主题、当前语言与本地化委托。
class Sub2apiApp extends ConsumerWidget {
  const Sub2apiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localeState = ref.watch(localeControllerProvider);
    final themeMode = ref.watch(themeControllerProvider);
    final registry = ref.watch(languagePackRegistryProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: router,
      // 跟随系统时交给 Flutter 按 supportedLocales 解析,否则用用户所选。
      locale: localeState.followSystem ? null : localeState.locale,
      supportedLocales: localeState.supportedLocales.isEmpty
          ? const [Locale('en')]
          : localeState.supportedLocales,
      localizationsDelegates: [
        AppLocalizationsDelegate(registry),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
