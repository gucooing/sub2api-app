import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../i18n/app_localizations.dart';
import '../providers/admin_accounts_providers.dart';

/// 账号池筛选值(对照 web AccountTableFilters)。
class AccountFilterValues {
  const AccountFilterValues({
    this.status = '',
    this.platform = '',
    this.type = '',
    this.group = '',
    this.privacyMode = '',
  });

  final String status;
  final String platform;
  final String type;
  final String group;
  final String privacyMode;
}

/// 底部弹层「更多筛选」(类似登录页选服务器),按需展开全部条件。
Future<AccountFilterValues?> showAccountFilterSheet(
  BuildContext context,
  WidgetRef ref, {
  required AccountFilterValues initial,
}) {
  return showModalBottomSheet<AccountFilterValues>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _FilterSheet(ref: ref, initial: initial),
  );
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.ref, required this.initial});
  final WidgetRef ref;
  final AccountFilterValues initial;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String _status = widget.initial.status;
  late String _platform = widget.initial.platform;
  late String _type = widget.initial.type;
  late String _group = widget.initial.group;
  late String _privacy = widget.initial.privacyMode;

  @override
  Widget build(BuildContext context) {
    final groupsAsync = widget.ref.watch(adminGroupsAllProvider);
    final groupItems = <(String, String)>[
      ('', context.tr('adminAccounts.allGroups')),
      ('ungrouped', context.tr('adminAccounts.ungrouped')),
      ...groupsAsync.maybeWhen(
        data: (gs) => [for (final g in gs) ('${g.id}', g.name)],
        orElse: () => const [],
      ),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.tr('adminAccounts.filters'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _sel(context, context.tr('adminAccounts.status'), _status, const {
              '': 'adminAccounts.statusAll',
              'active': 'adminAccounts.statusActive',
              'inactive': 'adminAccounts.statusInactive',
              'error': 'adminAccounts.statusError',
              'rate_limited': 'adminAccounts.status.rateLimited',
              'temp_unschedulable': 'adminAccounts.status.tempUnschedulable',
              'unschedulable': 'adminAccounts.status.unschedulable',
            }, (v) => setState(() => _status = v)),
            _sel(context, context.tr('adminAccounts.platform'), _platform,
                const {
                  '': 'adminAccounts.platformAll',
                  'anthropic': 'adminAccounts.platformAnthropic',
                  'openai': 'adminAccounts.platformOpenai',
                  'gemini': 'adminAccounts.platformGemini',
                  'antigravity': 'adminAccounts.platformAntigravity',
                }, (v) => setState(() => _platform = v)),
            _sel(context, context.tr('adminAccounts.type'), _type, const {
              '': 'adminAccounts.typeAll',
              'oauth': 'adminAccounts.typeOauth',
              'setup-token': 'adminAccounts.typeSetupToken',
              'apikey': 'adminAccounts.typeApikey',
              'bedrock': 'adminAccounts.typeBedrock',
            }, (v) => setState(() => _type = v)),
            _sel(context, context.tr('adminAccounts.privacy'), _privacy, const {
              '': 'adminAccounts.privacyAll',
              '__unset__': 'adminAccounts.privacyUnset',
              'training_off': 'adminAccounts.privacyOff',
              'training_set_cf_blocked': 'adminAccounts.privacyCf',
              'training_set_failed': 'adminAccounts.privacyFail',
            }, (v) => setState(() => _privacy = v)),
            _selRaw(context, context.tr('adminAccounts.groups'), _group,
                groupItems, (v) => setState(() => _group = v)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context)
                        .pop(const AccountFilterValues()),
                    child: Text(context.tr('adminAccounts.reset')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(
                      AccountFilterValues(
                        status: _status,
                        platform: _platform,
                        type: _type,
                        group: _group,
                        privacyMode: _privacy,
                      ),
                    ),
                    child: Text(context.tr('adminAccounts.apply')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sel(BuildContext context, String label, String value,
      Map<String, String> items, ValueChanged<String> onChanged) {
    return _selRaw(
      context,
      label,
      value,
      [for (final e in items.entries) (e.key, context.tr(e.value))],
      onChanged,
    );
  }

  Widget _selRaw(BuildContext context, String label, String value,
      List<(String, String)> items, ValueChanged<String> onChanged) {
    final valid = items.any((e) => e.$1 == value) ? value : '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        initialValue: valid,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        items: [
          for (final e in items)
            DropdownMenuItem(value: e.$1, child: Text(e.$2)),
        ],
        onChanged: (v) => onChanged(v ?? ''),
      ),
    );
  }
}
