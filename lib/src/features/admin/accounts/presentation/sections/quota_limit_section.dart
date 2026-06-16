import 'package:flutter/material.dart';

import '../../../../../i18n/app_localizations.dart';
import '../../../../../shared/widgets/pill_segmented.dart';
import '../../data/account_quota.dart';

const List<String> _timezones = [
  'UTC', 'Asia/Shanghai', 'Asia/Tokyo', 'Asia/Seoul', 'Asia/Singapore',
  'Asia/Kolkata', 'Asia/Dubai', 'Europe/London', 'Europe/Paris',
  'Europe/Berlin', 'Europe/Moscow', 'America/New_York', 'America/Chicago',
  'America/Denver', 'America/Los_Angeles', 'America/Sao_Paulo',
  'Australia/Sydney', 'Pacific/Auckland',
];

/// 星期:value 对照后端(0=周日..6=周六),展示用 i18n key。
const List<(int, String)> _weekDays = [
  (1, 'monday'), (2, 'tuesday'), (3, 'wednesday'), (4, 'thursday'),
  (5, 'friday'), (6, 'saturday'), (0, 'sunday'),
];

/// 配额控制区块(总/日/周额度 + 重置模式 + 阈值通知)。适用 apikey / bedrock。
class QuotaLimitSection extends StatefulWidget {
  const QuotaLimitSection({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.notifyGlobalEnabled = false,
  });

  final QuotaLimitValue value;
  final ValueChanged<QuotaLimitValue> onChanged;
  final bool enabled;

  /// 全局是否开启「账号配额通知」,关闭时不显示通知配置(对照 web)。
  final bool notifyGlobalEnabled;

  @override
  State<QuotaLimitSection> createState() => _QuotaLimitSectionState();
}

class _QuotaLimitSectionState extends State<QuotaLimitSection> {
  late QuotaLimitValue _v;
  late bool _on;
  late final TextEditingController _total;
  late final TextEditingController _daily;
  late final TextEditingController _weekly;
  late final TextEditingController _nTotal;
  late final TextEditingController _nDaily;
  late final TextEditingController _nWeekly;

  @override
  void initState() {
    super.initState();
    _v = widget.value;
    _on = _v.enabled;
    _total = TextEditingController(text: _numText(_v.total));
    _daily = TextEditingController(text: _numText(_v.daily));
    _weekly = TextEditingController(text: _numText(_v.weekly));
    _nTotal = TextEditingController(text: _numText(_v.notifyTotal.threshold));
    _nDaily = TextEditingController(text: _numText(_v.notifyDaily.threshold));
    _nWeekly = TextEditingController(text: _numText(_v.notifyWeekly.threshold));
  }

  static String _numText(num? v) => v == null ? '' : '$v';

  @override
  void dispose() {
    for (final c in [_total, _daily, _weekly, _nTotal, _nDaily, _nWeekly]) {
      c.dispose();
    }
    super.dispose();
  }

  void _emit() => widget.onChanged(_v);

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
                  Text(context.tr('adminAccounts.quota.toggle'),
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  Text(context.tr('adminAccounts.quota.toggleHint'),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            Switch(
              value: _on,
              onChanged: widget.enabled
                  ? (v) {
                      setState(() {
                        _on = v;
                        if (!v) {
                          _v.total = _v.daily = _v.weekly = null;
                          _v.dailyResetMode = _v.weeklyResetMode = 'rolling';
                          _v.notifyDaily = QuotaNotify();
                          _v.notifyWeekly = QuotaNotify();
                          _v.notifyTotal = QuotaNotify();
                          _total.clear();
                          _daily.clear();
                          _weekly.clear();
                          _nDaily.clear();
                          _nWeekly.clear();
                          _nTotal.clear();
                        }
                      });
                      _emit();
                    }
                  : null,
            ),
          ],
        ),
        if (_on) ...[
          const SizedBox(height: 8),
          _dimDaily(theme),
          const Divider(height: 24),
          _dimWeekly(theme),
          const Divider(height: 24),
          _dimTotal(theme),
        ],
      ],
    );
  }

  // ===== 维度行 =====
  Widget _dimDaily(ThemeData theme) => _dimension(
        theme,
        label: context.tr('adminAccounts.quota.daily'),
        limitCtrl: _daily,
        onLimit: (v) => _v.daily = v,
        resetMode: _v.dailyResetMode,
        onResetMode: (m) => setState(() {
          _v.dailyResetMode = m;
          _emit();
        }),
        resetHour: _v.dailyResetHour,
        onResetHour: (h) => setState(() {
          _v.dailyResetHour = h;
          _emit();
        }),
        notify: _v.notifyDaily,
        notifyCtrl: _nDaily,
      );

  Widget _dimWeekly(ThemeData theme) => _dimension(
        theme,
        label: context.tr('adminAccounts.quota.weekly'),
        limitCtrl: _weekly,
        onLimit: (v) => _v.weekly = v,
        resetMode: _v.weeklyResetMode,
        onResetMode: (m) => setState(() {
          _v.weeklyResetMode = m;
          _emit();
        }),
        resetHour: _v.weeklyResetHour,
        onResetHour: (h) => setState(() {
          _v.weeklyResetHour = h;
          _emit();
        }),
        weeklyDay: _v.weeklyResetDay,
        onWeeklyDay: (d) => setState(() {
          _v.weeklyResetDay = d;
          _emit();
        }),
        notify: _v.notifyWeekly,
        notifyCtrl: _nWeekly,
      );

  Widget _dimTotal(ThemeData theme) => _dimension(
        theme,
        label: context.tr('adminAccounts.quota.total'),
        limitCtrl: _total,
        onLimit: (v) => _v.total = v,
        notify: _v.notifyTotal,
        notifyCtrl: _nTotal,
      );

  Widget _dimension(
    ThemeData theme, {
    required String label,
    required TextEditingController limitCtrl,
    required ValueChanged<num?> onLimit,
    String? resetMode,
    ValueChanged<String>? onResetMode,
    int? resetHour,
    ValueChanged<int>? onResetHour,
    int? weeklyDay,
    ValueChanged<int>? onWeeklyDay,
    required QuotaNotify notify,
    required TextEditingController notifyCtrl,
  }) {
    final hasReset = resetMode != null && onResetMode != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: limitCtrl,
          enabled: widget.enabled,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            prefixText: '\$ ',
            isDense: true,
            border: const OutlineInputBorder(),
            hintText: context.tr('adminAccounts.quota.limitHint'),
          ),
          onChanged: (t) {
            onLimit(num.tryParse(t.trim()));
            _emit();
          },
        ),
        if (hasReset) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: PillSegmented<String>(
              selected: resetMode,
              onChanged: widget.enabled ? onResetMode : (_) {},
              options: [
                ('rolling', context.tr('adminAccounts.quota.rolling')),
                ('fixed', context.tr('adminAccounts.quota.fixed')),
              ],
            ),
          ),
          if (resetMode == 'fixed') ...[
            const SizedBox(height: 8),
            Row(children: [
              if (weeklyDay != null && onWeeklyDay != null) ...[
                Expanded(
                  child: _dropdown<int>(
                    label: context.tr('adminAccounts.quota.resetDay'),
                    value: weeklyDay,
                    items: [
                      for (final (v, k) in _weekDays)
                        (v, context.tr('adminAccounts.dayOfWeek.$k')),
                    ],
                    onChanged: onWeeklyDay,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: _dropdown<int>(
                  label: context.tr('adminAccounts.quota.resetHour'),
                  value: resetHour ?? 0,
                  items: [for (var h = 0; h < 24; h++) (h, '${h.toString().padLeft(2, '0')}:00')],
                  onChanged: onResetHour!,
                ),
              ),
            ]),
            const SizedBox(height: 8),
            _dropdown<String>(
              label: context.tr('adminAccounts.quota.timezone'),
              value: _timezones.contains(_v.resetTimezone)
                  ? _v.resetTimezone
                  : 'UTC',
              items: [for (final t in _timezones) (t, t)],
              onChanged: (t) => setState(() {
                _v.resetTimezone = t;
                _emit();
              }),
            ),
          ],
        ],
        if (widget.notifyGlobalEnabled) _notifyRow(theme, notify, notifyCtrl),
      ],
    );
  }

  Widget _notifyRow(
      ThemeData theme, QuotaNotify notify, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(context.tr('adminAccounts.quota.notify'),
                  style: theme.textTheme.bodySmall),
            ),
            Switch(
              value: notify.enabled,
              onChanged: widget.enabled
                  ? (v) {
                      setState(() => notify.enabled = v);
                      _emit();
                    }
                  : null,
            ),
          ]),
          if (notify.enabled)
            Row(children: [
              Expanded(
                child: TextField(
                  controller: ctrl,
                  enabled: widget.enabled,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    isDense: true,
                    border: const OutlineInputBorder(),
                    hintText: context.tr('adminAccounts.quota.threshold'),
                  ),
                  onChanged: (t) {
                    notify.threshold = num.tryParse(t.trim());
                    _emit();
                  },
                ),
              ),
              const SizedBox(width: 8),
              PillSegmented<QuotaThresholdType>(
                selected: notify.type,
                onChanged: widget.enabled
                    ? (t) {
                        setState(() => notify.type = t);
                        _emit();
                      }
                    : (_) {},
                options: const [
                  (QuotaThresholdType.fixed, '\$'),
                  (QuotaThresholdType.percentage, '%'),
                ],
              ),
            ]),
        ],
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T value,
    required List<(T, String)> items,
    required ValueChanged<T> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final (v, l) in items) DropdownMenuItem(value: v, child: Text(l)),
      ],
      onChanged: widget.enabled ? (v) => onChanged(v as T) : null,
    );
  }
}
