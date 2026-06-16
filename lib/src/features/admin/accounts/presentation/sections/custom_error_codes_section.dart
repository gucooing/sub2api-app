import 'package:flutter/material.dart';

import '../../../../../i18n/app_localizations.dart';
import '../../../../../shared/widgets/app_toast.dart';
import '../../../../../shared/widgets/confirm_dialog.dart';
import '../../data/account_model_mapping.dart';

/// 自定义错误码编辑值。
class CustomErrorCodesValue {
  CustomErrorCodesValue({this.enabled = false, List<int>? codes})
      : codes = codes ?? [];
  bool enabled;
  List<int> codes;
}

/// 自定义错误码区块(对照 web「Custom Error Codes」):仅 apikey 类型。
class CustomErrorCodesSection extends StatefulWidget {
  const CustomErrorCodesSection({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final CustomErrorCodesValue value;
  final ValueChanged<CustomErrorCodesValue> onChanged;
  final bool enabled;

  @override
  State<CustomErrorCodesSection> createState() =>
      _CustomErrorCodesSectionState();
}

class _CustomErrorCodesSectionState extends State<CustomErrorCodesSection> {
  late bool _enabled;
  late List<int> _codes;
  final _input = TextEditingController();

  @override
  void initState() {
    super.initState();
    _enabled = widget.value.enabled;
    _codes = [...widget.value.codes];
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _emit() =>
      widget.onChanged(CustomErrorCodesValue(enabled: _enabled, codes: [..._codes]));

  /// 429/529 加入前二次确认(对照 web 的 confirm)。
  Future<bool> _confirmDanger(int code) async {
    if (code != 429 && code != 529) return true;
    final key = code == 429
        ? 'adminAccounts.errorCodes.warn429'
        : 'adminAccounts.errorCodes.warn529';
    return await showConfirmDialog(
          context,
          title: context.tr('adminAccounts.errorCodes.label'),
          message: context.tr(key),
        ) ==
        true;
  }

  Future<void> _toggle(int code) async {
    if (_codes.contains(code)) {
      setState(() => _codes.remove(code));
      _emit();
      return;
    }
    if (!await _confirmDanger(code)) return;
    setState(() => _codes.add(code));
    _emit();
  }

  Future<void> _addManual() async {
    final n = int.tryParse(_input.text.trim());
    if (n == null || n < 100 || n > 599) {
      showAppToast(context, context.tr('adminAccounts.errorCodes.invalid'),
          error: true);
      return;
    }
    if (_codes.contains(n)) {
      showAppToast(context, context.tr('adminAccounts.errorCodes.exists'));
      return;
    }
    if (!await _confirmDanger(n)) return;
    setState(() => _codes.add(n));
    _input.clear();
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sorted = [..._codes]..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.tr('adminAccounts.errorCodes.label'),
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  Text(context.tr('adminAccounts.errorCodes.hint'),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            Switch(
              value: _enabled,
              onChanged: widget.enabled
                  ? (v) {
                      setState(() => _enabled = v);
                      _emit();
                    }
                  : null,
            ),
          ],
        ),
        if (_enabled) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(context.tr('adminAccounts.errorCodes.warning'),
                style: theme.textTheme.bodySmall),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final c in kCommonErrorCodes)
                FilterChip(
                  label: Text('${c.value} ${c.label}'),
                  selected: _codes.contains(c.value),
                  onSelected:
                      widget.enabled ? (_) => _toggle(c.value) : null,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _input,
                enabled: widget.enabled,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  isDense: true,
                  border: const OutlineInputBorder(),
                  hintText: context.tr('adminAccounts.errorCodes.enterCode'),
                ),
                onSubmitted: (_) => _addManual(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: widget.enabled ? _addManual : null,
              icon: const Icon(Icons.add),
            ),
          ]),
          const SizedBox(height: 10),
          if (sorted.isEmpty)
            Text(context.tr('adminAccounts.errorCodes.noneSelected'),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant))
          else
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final c in sorted)
                  InputChip(
                    label: Text('$c'),
                    onDeleted: widget.enabled ? () => _toggle(c) : null,
                  ),
              ],
            ),
        ],
      ],
    );
  }
}
