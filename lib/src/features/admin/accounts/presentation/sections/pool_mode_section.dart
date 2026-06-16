import 'package:flutter/material.dart';

import '../../../../../i18n/app_localizations.dart';

/// 池模式编辑值。
class PoolModeValue {
  PoolModeValue({
    this.enabled = false,
    this.retryCount = 3,
    this.retryStatusCodesInput = '',
  });
  bool enabled;
  int retryCount;
  String retryStatusCodesInput;
}

const int kDefaultPoolModeRetryCount = 3;
const int kMaxPoolModeRetryCount = 10;
const String kDefaultPoolModeRetryCodes = '401, 403, 429';

/// 池模式区块(对照 web「Pool Mode」):开关 + 重试次数 + 重试状态码。
/// 仅 apikey/bedrock 类型显示。
class PoolModeSection extends StatefulWidget {
  const PoolModeSection({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final PoolModeValue value;
  final ValueChanged<PoolModeValue> onChanged;
  final bool enabled;

  @override
  State<PoolModeSection> createState() => _PoolModeSectionState();
}

class _PoolModeSectionState extends State<PoolModeSection> {
  late bool _enabled;
  late final TextEditingController _count;
  late final TextEditingController _codes;

  @override
  void initState() {
    super.initState();
    _enabled = widget.value.enabled;
    _count = TextEditingController(text: '${widget.value.retryCount}');
    _codes = TextEditingController(text: widget.value.retryStatusCodesInput);
  }

  @override
  void dispose() {
    _count.dispose();
    _codes.dispose();
    super.dispose();
  }

  void _emit() {
    var n = int.tryParse(_count.text.trim()) ?? kDefaultPoolModeRetryCount;
    n = n.clamp(0, kMaxPoolModeRetryCount);
    widget.onChanged(PoolModeValue(
      enabled: _enabled,
      retryCount: n,
      retryStatusCodesInput: _codes.text,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.tr('adminAccounts.poolMode.label'),
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  Text(context.tr('adminAccounts.poolMode.hint'),
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
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(context.tr('adminAccounts.poolMode.info'),
                style: theme.textTheme.bodySmall),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _count,
            enabled: widget.enabled,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: context.tr('adminAccounts.poolMode.retryCount'),
              helperText: context.tr('adminAccounts.poolMode.retryCountHint',
                  params: {
                    'default': '$kDefaultPoolModeRetryCount',
                    'max': '$kMaxPoolModeRetryCount'
                  }),
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => _emit(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _codes,
            enabled: widget.enabled,
            decoration: InputDecoration(
              labelText: context.tr('adminAccounts.poolMode.retryCodes'),
              hintText: kDefaultPoolModeRetryCodes,
              helperText: context.tr('adminAccounts.poolMode.retryCodesHint',
                  params: {'default': kDefaultPoolModeRetryCodes}),
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => _emit(),
          ),
        ],
      ],
    );
  }
}
