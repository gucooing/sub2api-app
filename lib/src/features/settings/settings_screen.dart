import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/preferences/external_browser_controller.dart';
import '../../core/server/server_store.dart';
import '../../core/theme/theme_controller.dart';
import '../../i18n/app_localizations.dart';
import '../../i18n/language_pack_loader.dart';
import '../../i18n/locale_controller.dart';

/// 设置页:演示并驱动主题切换、语言切换、外置语言包热重载。
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localeState = ref.watch(localeControllerProvider);
    final themeMode = ref.watch(themeControllerProvider);
    final useExternalBrowser = ref.watch(externalBrowserProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('settings.title'))),
      body: ListView(
        children: [
          _SectionHeader(context.tr('settings.appearance')),

          // 主题模式
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: Text(context.tr('settings.theme')),
            subtitle: Text(_themeLabel(context, themeMode)),
          ),
          _ThemeSegmented(themeMode: themeMode),

          const Divider(height: 32),
          _SectionHeader(context.tr('settings.language')),

          // 语言单选组:null 表示「跟随系统」,其余为具体语言包标签。
          RadioGroup<String?>(
            groupValue: localeState.followSystem ? null : localeState.currentTag,
            onChanged: (value) {
              final controller = ref.read(localeControllerProvider.notifier);
              if (value == null) {
                controller.useSystemLocale();
              } else {
                controller.setLocale(value);
              }
            },
            child: Column(
              children: [
                RadioListTile<String?>(
                  value: null,
                  title: Text(context.tr('settings.languageFollowSystem')),
                ),
                for (final pack in localeState.packs)
                  RadioListTile<String?>(
                    value: pack.tag,
                    title: Text(pack.nativeName),
                    subtitle: Text(pack.tag),
                  ),
              ],
            ),
          ),

          const Divider(height: 32),
          _SectionHeader(context.tr('settings.languagePacks')),
          _ExternalPacksTile(),

          const Divider(height: 32),
          _SectionHeader(context.tr('settings.browser')),
          SwitchListTile(
            secondary: const Icon(Icons.open_in_browser_outlined),
            title: Text(context.tr('settings.externalBrowser')),
            subtitle: Text(context.tr('settings.externalBrowserHint')),
            value: useExternalBrowser,
            onChanged: (v) =>
                ref.read(externalBrowserProvider.notifier).set(v),
          ),

          const Divider(height: 32),
          _SectionHeader(context.tr('servers.title')),
          ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: Text(context.tr('servers.title')),
            subtitle: Text(ref.watch(activeServerProvider).name),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/servers'),
          ),

          const Divider(height: 32),
          _SectionHeader(context.tr('settings.about')),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(context.tr('settings.version')),
            subtitle: const Text(AppConfig.appName),
            trailing: const Text('0.1.0'),
          ),
        ],
      ),
    );
  }

  String _themeLabel(BuildContext context, ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return context.tr('settings.themeLight');
      case ThemeMode.dark:
        return context.tr('settings.themeDark');
      case ThemeMode.system:
        return context.tr('settings.themeSystem');
    }
  }
}

class _ThemeSegmented extends ConsumerWidget {
  const _ThemeSegmented({required this.themeMode});

  final ThemeMode themeMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SegmentedButton<ThemeMode>(
        segments: [
          ButtonSegment(
            value: ThemeMode.system,
            label: Text(context.tr('settings.themeSystem')),
            icon: const Icon(Icons.brightness_auto_outlined),
          ),
          ButtonSegment(
            value: ThemeMode.light,
            label: Text(context.tr('settings.themeLight')),
            icon: const Icon(Icons.light_mode_outlined),
          ),
          ButtonSegment(
            value: ThemeMode.dark,
            label: Text(context.tr('settings.themeDark')),
            icon: const Icon(Icons.dark_mode_outlined),
          ),
        ],
        selected: {themeMode},
        onSelectionChanged: (sel) =>
            ref.read(themeControllerProvider.notifier).setMode(sel.first),
      ),
    );
  }
}

class _ExternalPacksTile extends ConsumerStatefulWidget {
  @override
  ConsumerState<_ExternalPacksTile> createState() => _ExternalPacksTileState();
}

class _ExternalPacksTileState extends ConsumerState<_ExternalPacksTile> {
  String? _dirPath;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    LanguagePackLoader().externalDir().then((dir) {
      if (mounted) setState(() => _dirPath = dir.path);
    });
  }

  Future<void> _reload() async {
    setState(() => _busy = true);
    await ref.read(localeControllerProvider.notifier).reloadPacks();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr('settings.packReloaded'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            context.tr('settings.externalPackHint'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        if (_dirPath != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SelectableText(
              _dirPath!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _reload,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            label: Text(context.tr('settings.reloadPacks')),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
