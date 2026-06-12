import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../i18n/app_localizations.dart';
import '../data/keys_api.dart';
import '../providers/keys_providers.dart';

/// 打开创建([existing] 为空)或编辑密钥的底部弹窗。
Future<void> showKeyEditSheet(BuildContext context, WidgetRef ref,
    {ApiKeyInfo? existing}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _KeyEditForm(existing: existing),
    ),
  );
}

class _KeyEditForm extends ConsumerStatefulWidget {
  const _KeyEditForm({this.existing});

  final ApiKeyInfo? existing;

  @override
  ConsumerState<_KeyEditForm> createState() => _KeyEditFormState();
}

class _KeyEditFormState extends ConsumerState<_KeyEditForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _quota = TextEditingController(
    text: (widget.existing?.quota ?? 0) > 0
        ? widget.existing!.quota.toStringAsFixed(2)
        : '',
  );
  final _expiresDays = TextEditingController();

  int? _groupId;
  bool _busy = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _groupId = widget.existing?.groupId;
  }

  @override
  void dispose() {
    _name.dispose();
    _quota.dispose();
    _expiresDays.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final api = ref.read(keysApiProvider);
    final quota = double.tryParse(_quota.text.trim());
    try {
      if (_isEdit) {
        await api.update(
          widget.existing!.id,
          name: _name.text.trim(),
          groupId: _groupId,
          quota: quota ?? 0,
        );
      } else {
        final created = await api.create(
          name: _name.text.trim(),
          groupId: _groupId,
          quota: quota,
          expiresInDays: int.tryParse(_expiresDays.text.trim()),
        );
        if (mounted) {
          Navigator.of(context).pop();
          await _showCreatedDialog(created);
        }
      }
      ref.invalidate(keysListProvider);
      if (_isEdit && mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.localizedMessage(context);
        });
      }
    }
  }

  Future<void> _showCreatedDialog(ApiKeyInfo created) {
    final rootContext = ref.context;
    return showDialog<void>(
      context: rootContext,
      builder: (context) => AlertDialog(
        title: Text(context.tr('keys.createdTitle')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('keys.createdHint')),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                created.key,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ),
          ],
        ),
        actions: [
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: created.key));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.tr('common.copied'))),
                );
                Navigator.of(context).pop();
              }
            },
            icon: const Icon(Icons.copy, size: 18),
            label: Text(context.tr('common.copy')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(availableGroupsProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEdit ? context.tr('keys.edit') : context.tr('keys.create'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _name,
              enabled: !_busy,
              decoration: InputDecoration(
                labelText: context.tr('keys.name'),
                border: const OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? context.tr('keys.nameRequired')
                  : null,
            ),
            const SizedBox(height: 16),
            // 分组选择(可空 = 默认分组)
            groups.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => const SizedBox.shrink(),
              data: (list) => DropdownButtonFormField<int?>(
                initialValue: _groupId,
                decoration: InputDecoration(
                  labelText: context.tr('keys.group'),
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem<int?>(
                    value: null,
                    child: Text(context.tr('keys.groupDefault')),
                  ),
                  for (final g in list)
                    DropdownMenuItem<int?>(
                      value: g.id,
                      child: Text(
                        g.rateMultiplier != 1
                            ? '${g.name} (x${g.rateMultiplier})'
                            : g.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged:
                    _busy ? null : (v) => setState(() => _groupId = v),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _quota,
              enabled: !_busy,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText:
                    '${context.tr('keys.quota')} (${context.tr('keys.quotaHint')})',
                prefixText: '\$ ',
                border: const OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                return double.tryParse(v.trim()) == null
                    ? context.tr('keys.quotaInvalid')
                    : null;
              },
            ),
            if (!_isEdit) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _expiresDays,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText:
                      '${context.tr('keys.expiresInDays')} (${context.tr('common.optional')})',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(context.tr('common.save')),
            ),
          ],
        ),
      ),
    );
  }
}
