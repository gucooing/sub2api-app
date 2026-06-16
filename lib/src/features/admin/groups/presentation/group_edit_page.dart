import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../i18n/app_localizations.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../shared/widgets/error_retry.dart';
import '../../../../shared/widgets/responsive.dart';
import '../../../../shared/widgets/section_header.dart';
import '../data/admin_groups_api.dart';
import '../providers/admin_groups_providers.dart';

/// 分组 新增 / 编辑:核心字段(名称/平台/倍率/RPM/独占/Claude Code/限额/状态)。
/// 编辑态额外入口:用户专属倍率 / RPM 覆盖。
class GroupEditPage extends ConsumerStatefulWidget {
  const GroupEditPage({super.key, this.groupId});

  final int? groupId;
  bool get isEdit => groupId != null;

  @override
  ConsumerState<GroupEditPage> createState() => _GroupEditPageState();
}

class _GroupEditPageState extends ConsumerState<GroupEditPage> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _rate = TextEditingController(text: '1');
  final _rpm = TextEditingController(text: '0');
  final _daily = TextEditingController();
  final _weekly = TextEditingController();
  final _monthly = TextEditingController();

  String _platform = 'anthropic';
  bool _exclusive = false;
  bool _claudeCodeOnly = false;
  bool _active = true;
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _desc, _rate, _rpm, _daily, _weekly, _monthly]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = context.tr(
        widget.isEdit ? 'adminGroups.editTitle' : 'adminGroups.addTitle');
    if (!widget.isEdit) {
      return Scaffold(appBar: AppBar(title: Text(title)), body: _form());
    }
    final async = ref.watch(adminGroupDetailProvider(widget.groupId!));
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorRetryView(
          error: e,
          onRetry: () => ref.invalidate(adminGroupDetailProvider(widget.groupId!)),
        ),
        data: (g) {
          if (!_initialized) {
            _initialized = true;
            _prefill(g);
          }
          return _form();
        },
      ),
    );
  }

  void _prefill(AdminGroup g) {
    _name.text = g.name;
    _desc.text = g.description ?? '';
    _platform = g.platform.isEmpty ? 'anthropic' : g.platform;
    _rate.text = '${g.rateMultiplier}';
    _rpm.text = '${g.rpmLimit ?? 0}';
    _daily.text = g.dailyLimitUsd?.toString() ?? '';
    _weekly.text = g.weeklyLimitUsd?.toString() ?? '';
    _monthly.text = g.monthlyLimitUsd?.toString() ?? '';
    _exclusive = g.isExclusive;
    _claudeCodeOnly = g.claudeCodeOnly;
    _active = g.isActive;
  }

  Widget _form() {
    return ResponsiveCenter(
      maxWidth: 640,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          SectionHeader(title: context.tr('adminGroups.sec.basic')),
          _field(_name, 'adminGroups.fName'),
          _field(_desc, 'adminGroups.fDesc', optional: true, lines: 2),
          if (!widget.isEdit)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<String>(
                initialValue: _platform,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: context.tr('adminGroups.platform'),
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'anthropic', child: Text('Anthropic')),
                  DropdownMenuItem(value: 'openai', child: Text('OpenAI')),
                  DropdownMenuItem(value: 'gemini', child: Text('Gemini')),
                  DropdownMenuItem(
                      value: 'antigravity', child: Text('Antigravity')),
                ],
                onChanged:
                    _saving ? null : (v) => setState(() => _platform = v ?? 'anthropic'),
              ),
            ),
          if (widget.isEdit)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.tr('adminGroups.statusActive')),
              value: _active,
              onChanged: _saving ? null : (v) => setState(() => _active = v),
            ),

          const SizedBox(height: 8),
          SectionHeader(title: context.tr('adminGroups.sec.billing')),
          Row(children: [
            Expanded(
                child: _field(_rate, 'adminGroups.rateMultiplier', number: true)),
            const SizedBox(width: 12),
            Expanded(
                child: _field(_rpm, 'adminGroups.rpmLimit',
                    number: true, hint: 'adminGroups.rpmHint')),
          ]),
          Row(children: [
            Expanded(
                child: _field(_daily, 'adminGroups.daily',
                    number: true, optional: true)),
            const SizedBox(width: 12),
            Expanded(
                child: _field(_weekly, 'adminGroups.weekly',
                    number: true, optional: true)),
            const SizedBox(width: 12),
            Expanded(
                child: _field(_monthly, 'adminGroups.monthly',
                    number: true, optional: true)),
          ]),

          const SizedBox(height: 8),
          SectionHeader(title: context.tr('adminGroups.sec.policy')),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.tr('adminGroups.exclusive')),
            subtitle: Text(context.tr('adminGroups.exclusiveHint')),
            value: _exclusive,
            onChanged: _saving ? null : (v) => setState(() => _exclusive = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Claude Code Only'),
            subtitle: Text(context.tr('adminGroups.claudeCodeOnlyHint')),
            value: _claudeCodeOnly,
            onChanged: _saving ? null : (v) => setState(() => _claudeCodeOnly = v),
          ),

          if (widget.isEdit) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => context.push('/admin/groups/${widget.groupId}/rates'),
              icon: const Icon(Icons.tune, size: 18),
              label: Text(context.tr('adminGroups.rateEditor')),
            ),
          ],

          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(context.tr('common.save')),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      showAppToast(context, context.tr('adminGroups.nameRequired'), error: true);
      return;
    }
    setState(() => _saving = true);
    final api = ref.read(adminGroupsApiProvider);
    num? pNum(TextEditingController c) => num.tryParse(c.text.trim());
    try {
      final body = <String, dynamic>{
        'name': _name.text.trim(),
        'description': _desc.text.trim(),
        'rate_multiplier': pNum(_rate) ?? 1,
        'rpm_limit': int.tryParse(_rpm.text.trim()) ?? 0,
        'is_exclusive': _exclusive,
        'claude_code_only': _claudeCodeOnly,
        'daily_limit_usd': pNum(_daily),
        'weekly_limit_usd': pNum(_weekly),
        'monthly_limit_usd': pNum(_monthly),
      };
      if (widget.isEdit) {
        body['status'] = _active ? 'active' : 'inactive';
        await api.update(widget.groupId!, body);
        ref.invalidate(adminGroupDetailProvider(widget.groupId!));
      } else {
        body['platform'] = _platform;
        await api.create(body);
      }
      ref.invalidate(adminGroupsControllerProvider);
      if (mounted) {
        showAppToast(context, context.tr('common.done'));
        context.pop();
      }
    } catch (e) {
      if (mounted) showAppToast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(TextEditingController c, String labelKey,
      {bool number = false,
      bool optional = false,
      String? hint,
      int lines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        enabled: !_saving,
        maxLines: lines,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : null,
        decoration: InputDecoration(
          labelText: optional
              ? '${context.tr(labelKey)} (${context.tr('common.optional')})'
              : context.tr(labelKey),
          helperText: hint == null ? null : context.tr(hint),
          isDense: true,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
