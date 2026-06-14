import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/preferences/external_browser_controller.dart';
import '../../core/server/server_store.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/update/update_service.dart';
import '../../i18n/app_localizations.dart';
import '../../i18n/locale_controller.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/responsive.dart';
import 'update_check.dart';

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
      body: ResponsiveCenter(
        child: ListView(
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
            trailing: ref.watch(appVersionProvider).maybeWhen(
                  data: (v) => Text('v$v'),
                  orElse: () => const Text('—'),
                ),
          ),
          ListTile(
            leading: const Icon(Icons.schedule_outlined),
            title: Text(context.tr('settings.buildTime')),
            subtitle: Text(
              kBuildTime.isNotEmpty
                  ? kBuildTime
                  : context.tr('settings.localBuild'),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: Text(context.tr('settings.compatibleBackend')),
            subtitle: Text(context.tr('settings.compatibleBackendHint')),
            trailing: const Text('v${AppConfig.compatibleBackendVersion}'),
          ),
          ListTile(
            leading: const Icon(Icons.code_outlined),
            title: Text(context.tr('settings.repo')),
            subtitle: const Text(AppConfig.repoUrl),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => launchUrl(
              Uri.parse(AppConfig.repoUrl),
              mode: LaunchMode.externalApplication,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.system_update_outlined),
            title: Text(context.tr('settings.checkUpdate')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => runUpdateCheck(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long_outlined),
            title: Text(context.tr('logs.title')),
            subtitle: Text(context.tr('logs.subtitle')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/logs'),
          ),
          ListTile(
            leading: const Icon(Icons.feedback_outlined),
            title: Text(context.tr('settings.feedback')),
            subtitle: Text(context.tr('settings.feedbackHint')),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => launchUrl(
              Uri.parse('${AppConfig.repoUrl}/issues/new'),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ],
      ),
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
  /// 内置语言包标签(不可删除)。
  static const _builtInTags = {'zh-CN', 'en-US'};
  bool _busy = false;

  Future<void> _import() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    setState(() => _busy = true);
    try {
      final name =
          await ref.read(localeControllerProvider.notifier).importPack(path);
      if (mounted) {
        showAppToast(
          context,
          context.tr('settings.packImported', params: {'name': name}),
        );
      }
    } catch (_) {
      if (mounted) {
        showAppToast(context, context.tr('settings.importFailed'),
            error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(String tag, String name) async {
    final ok = await showConfirmDialog(
      context,
      title: context.tr('settings.deletePack'),
      message: context.tr('settings.deletePackConfirm', params: {'name': name}),
      confirmLabel: context.tr('common.delete'),
      destructive: true,
    );
    if (!ok) return;
    await ref.read(localeControllerProvider.notifier).deletePack(tag);
    if (mounted) showAppToast(context, context.tr('settings.packDeleted'));
  }

  @override
  Widget build(BuildContext context) {
    final packs = ref.watch(localeControllerProvider).packs;
    final imported =
        packs.where((p) => !_builtInTags.contains(p.tag)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            context.tr('settings.importPackHint'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _import,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_upload_outlined),
            label: Text(context.tr('settings.importPack')),
          ),
        ),
        if (imported.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              context.tr('settings.noImportedPacks'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          )
        else
          for (final p in imported)
            ListTile(
              dense: true,
              leading: const Icon(Icons.translate_outlined),
              title: Text(p.nativeName),
              subtitle: Text(p.tag),
              trailing: IconButton(
                icon: Icon(Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error),
                onPressed: () => _delete(p.tag, p.nativeName),
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
