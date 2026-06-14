import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../i18n/app_localizations.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../shared/widgets/error_retry.dart';
import '../../../../shared/widgets/responsive.dart';
import '../data/admin_setting_fields.dart';
import '../providers/admin_settings_providers.dart';

/// 单个设置大类的编辑页:按字段描述子渲染,保存只提交本类字段(部分更新)。
class AdminSettingCategoryPage extends ConsumerWidget {
  const AdminSettingCategoryPage({super.key, required this.categoryKey});

  final String categoryKey;

  SettingCategory? get _category {
    for (final c in kSettingCategories) {
      if (c.key == categoryKey) return c;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = _category;
    final async = ref.watch(adminSettingsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          category == null ? '' : context.tr(category.labelKey),
        ),
      ),
      body: category == null
          ? const SizedBox.shrink()
          : async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorRetryView(
                error: e,
                onRetry: () => ref.invalidate(adminSettingsProvider),
              ),
              data: (raw) => _Form(category: category, raw: raw),
            ),
    );
  }
}

class _Form extends ConsumerStatefulWidget {
  const _Form({required this.category, required this.raw});

  final SettingCategory category;
  final Map<String, dynamic> raw;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  final Map<String, TextEditingController> _text = {};
  final Map<String, bool> _bools = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final f in widget.category.fields) {
      final v = widget.raw[f.key];
      if (f.type == SettingFieldType.toggle) {
        _bools[f.key] = v == true;
      } else {
        _text[f.key] = TextEditingController(text: _initText(f, v));
      }
    }
  }

  static String _initText(SettingField f, dynamic v) {
    if (v == null) return '';
    if (f.type == SettingFieldType.number && v is num) {
      return v == v.roundToDouble() ? '${v.toInt()}' : '$v';
    }
    return '$v';
  }

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final patch = <String, dynamic>{};
    for (final f in widget.category.fields) {
      switch (f.type) {
        case SettingFieldType.toggle:
          patch[f.key] = _bools[f.key] ?? false;
          break;
        case SettingFieldType.number:
          final raw = _text[f.key]!.text.trim();
          final n = num.tryParse(raw) ?? 0;
          patch[f.key] = n == n.roundToDouble() ? n.toInt() : n;
          break;
        case SettingFieldType.text:
        case SettingFieldType.multiline:
          patch[f.key] = _text[f.key]!.text;
          break;
      }
    }
    try {
      await ref.read(adminSettingsApiProvider).update(patch);
      ref.invalidate(adminSettingsProvider);
      if (mounted) showAppToast(context, context.tr('admin.settings.saved'));
    } on ApiException catch (e) {
      if (mounted) {
        showAppToast(context, e.localizedMessage(context), error: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveCenter(
      maxWidth: 640,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          for (final f in widget.category.fields) _fieldWidget(f),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.tr('common.save')),
          ),
        ],
      ),
    );
  }

  Widget _fieldWidget(SettingField f) {
    final label = context.tr(f.labelKey);
    if (f.type == SettingFieldType.toggle) {
      return SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        value: _bools[f.key] ?? false,
        onChanged:
            _saving ? null : (v) => setState(() => _bools[f.key] = v),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: _text[f.key],
        enabled: !_saving,
        maxLines: f.type == SettingFieldType.multiline ? 4 : 1,
        keyboardType:
            f.type == SettingFieldType.number ? TextInputType.number : null,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }
}
