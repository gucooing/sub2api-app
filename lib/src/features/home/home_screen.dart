import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../i18n/app_localizations.dart';

/// 首页(占位)。当前用于演示 i18n + 主题贯通,后续阶段替换为真正的控制台。
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('nav.home')),
        actions: [
          IconButton(
            tooltip: context.tr('nav.settings'),
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.bolt, size: 56, color: Colors.white),
              ),
              const SizedBox(height: 24),
              Text(
                context.tr('home.welcome',
                    params: {'name': AppConfig.appName}),
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                context.tr('home.subtitle'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () => context.push('/settings'),
                icon: const Icon(Icons.settings_outlined),
                label: Text(context.tr('home.openSettings')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
