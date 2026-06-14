import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../i18n/app_localizations.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../shared/widgets/error_retry.dart';
import '../../../../shared/widgets/responsive.dart';
import '../providers/admin_accounts_providers.dart';

/// 账号 新增 / 编辑 表单。
/// - 新增:支持 apikey/bedrock 凭据型账号(name/platform/type/base_url/api_key/并发/
///   优先级/倍率/分组/备注);OAuth 授权流账号创建后续接入。
/// - 编辑:任意类型的基础字段(name/备注/并发/优先级/倍率/状态/分组),apikey 可改 base_url/api_key。
class AccountEditPage extends ConsumerStatefulWidget {
  const AccountEditPage({super.key, this.accountId});

  /// null = 新增;非 null = 编辑。
  final int? accountId;

  bool get isEdit => accountId != null;

  @override
  ConsumerState<AccountEditPage> createState() => _AccountEditPageState();
}

class _AccountEditPageState extends ConsumerState<AccountEditPage> {
  final _name = TextEditingController();
  final _baseUrl = TextEditingController();
  final _apiKey = TextEditingController();
  final _concurrency = TextEditingController(text: '1');
  final _priority = TextEditingController(text: '0');
  final _rate = TextEditingController();
  final _notes = TextEditingController();

  String _platform = 'anthropic';
  String _type = 'apikey';
  bool _active = true;
  final Set<int> _groupIds = {};

  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _baseUrl, _apiKey, _concurrency, _priority, _rate, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _isApiKeyType => _type == 'apikey' || _type == 'bedrock';

  @override
  Widget build(BuildContext context) {
    final title = context.tr(
        widget.isEdit ? 'adminAccounts.editTitle' : 'adminAccounts.addTitle');
    if (!widget.isEdit) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: _form(context),
      );
    }
    final async = ref.watch(adminAccountDetailProvider(widget.accountId!));
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorRetryView(
          error: e,
          onRetry: () =>
              ref.invalidate(adminAccountDetailProvider(widget.accountId!)),
        ),
        data: (a) {
          if (!_initialized) {
            _initialized = true;
            _name.text = a.name;
            _platform = a.platform.isEmpty ? 'anthropic' : a.platform;
            _type = a.type.isEmpty ? 'apikey' : a.type;
            _concurrency.text = '${a.concurrency}';
            _priority.text = '${a.priority}';
            _rate.text = a.rateMultiplier?.toString() ?? '';
            _notes.text = a.notes ?? '';
            _active = a.isActive;
          }
          return _form(context);
        },
      ),
    );
  }

  Widget _form(BuildContext context) {
    final groupsAsync = ref.watch(adminGroupsAllProvider);
    return ResponsiveCenter(
      maxWidth: 640,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _field(_name, 'adminAccounts.fName'),
          if (!widget.isEdit) ...[
            _dropdown('adminAccounts.platform', _platform, const {
              'anthropic': 'Anthropic',
              'openai': 'OpenAI',
              'gemini': 'Gemini',
              'antigravity': 'Antigravity',
            }, (v) => setState(() => _platform = v), raw: true),
            _dropdown('adminAccounts.type', _type, const {
              'apikey': 'adminAccounts.typeApikey',
              'bedrock': 'adminAccounts.typeBedrock',
            }, (v) => setState(() => _type = v)),
          ],
          if (_isApiKeyType) ...[
            _field(_baseUrl, 'adminAccounts.fBaseUrl', optional: true),
            _field(_apiKey, 'adminAccounts.fApiKey',
                optional: widget.isEdit,
                hint: widget.isEdit ? 'adminAccounts.fApiKeyEditHint' : null),
          ],
          Row(
            children: [
              Expanded(
                  child: _field(_concurrency, 'adminAccounts.concurrency',
                      number: true)),
              const SizedBox(width: 12),
              Expanded(
                  child: _field(_priority, 'adminAccounts.priority',
                      number: true)),
            ],
          ),
          _field(_rate, 'adminAccounts.rateMultiplier',
              number: true, optional: true),
          if (widget.isEdit)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.tr('adminAccounts.statusActive')),
              value: _active,
              onChanged: _saving ? null : (v) => setState(() => _active = v),
            ),
          const SizedBox(height: 8),
          Text(context.tr('adminAccounts.groups'),
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          groupsAsync.maybeWhen(
            data: (gs) => Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final g in gs)
                  FilterChip(
                    label: Text(g.name),
                    selected: _groupIds.contains(g.id),
                    onSelected: _saving
                        ? null
                        : (s) => setState(() =>
                            s ? _groupIds.add(g.id) : _groupIds.remove(g.id)),
                  ),
              ],
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(height: 8),
          _field(_notes, 'adminAccounts.notes', optional: true),
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
      showAppToast(context, context.tr('adminAccounts.nameRequired'), error: true);
      return;
    }
    setState(() => _saving = true);
    final api = ref.read(adminAccountsApiProvider);
    final rate = double.tryParse(_rate.text.trim());
    try {
      if (widget.isEdit) {
        final body = <String, dynamic>{
          'name': _name.text.trim(),
          'concurrency': int.tryParse(_concurrency.text.trim()) ?? 1,
          'priority': int.tryParse(_priority.text.trim()) ?? 0,
          'status': _active ? 'active' : 'inactive',
          'notes': _notes.text.trim(),
          'rate_multiplier': ?rate,
          if (_groupIds.isNotEmpty) 'group_ids': _groupIds.toList(),
          if (_isApiKeyType && _apiKey.text.trim().isNotEmpty)
            'credentials': {'api_key': _apiKey.text.trim()},
          if (_isApiKeyType && _baseUrl.text.trim().isNotEmpty)
            'base_url': _baseUrl.text.trim(),
        };
        await api.update(widget.accountId!, body);
      } else {
        final body = <String, dynamic>{
          'name': _name.text.trim(),
          'platform': _platform,
          'type': _type,
          'concurrency': int.tryParse(_concurrency.text.trim()) ?? 1,
          'priority': int.tryParse(_priority.text.trim()) ?? 0,
          'notes': _notes.text.trim(),
          'rate_multiplier': ?rate,
          if (_groupIds.isNotEmpty) 'group_ids': _groupIds.toList(),
          'credentials': {
            'api_key': _apiKey.text.trim(),
          },
          if (_baseUrl.text.trim().isNotEmpty) 'base_url': _baseUrl.text.trim(),
        };
        await api.create(body);
      }
      ref.invalidate(adminAccountsControllerProvider);
      if (widget.isEdit) {
        ref.invalidate(adminAccountDetailProvider(widget.accountId!));
      }
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
      {bool number = false, bool optional = false, String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        enabled: !_saving,
        keyboardType: number ? TextInputType.number : null,
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

  Widget _dropdown(String labelKey, String value, Map<String, String> items,
      ValueChanged<String> onChanged,
      {bool raw = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: context.tr(labelKey),
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        items: [
          for (final e in items.entries)
            DropdownMenuItem(
                value: e.key, child: Text(raw ? e.value : context.tr(e.value))),
        ],
        onChanged: _saving ? null : (v) => onChanged(v ?? value),
      ),
    );
  }
}
