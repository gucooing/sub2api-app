import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../i18n/app_localizations.dart';
import '../../../../shared/format/formatters.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../groups/data/admin_groups_api.dart';
import '../../groups/providers/admin_groups_providers.dart';
import '../data/admin_announcements_api.dart';
import '../providers/admin_announcements_providers.dart';

/// 公告定向条件草稿(可变,便于增删改)。
class _CondDraft {
  _CondDraft({
    required this.id,
    this.type = 'subscription',
    this.operator = 'in',
    Set<int>? groupIds,
    this.value,
  }) : groupIds = groupIds ?? <int>{};

  final int id;
  String type; // subscription / balance
  String operator; // in / gt / gte / lt / lte / eq
  Set<int> groupIds;
  num? value;
}

class _OrGroupDraft {
  _OrGroupDraft({List<_CondDraft>? conds}) : conds = conds ?? [];
  final List<_CondDraft> conds;
}

/// 公告新增/编辑(全功能对照 web:标题/内容/状态/通知方式/起止时间/受众定向)。
class AnnouncementEditPage extends ConsumerStatefulWidget {
  const AnnouncementEditPage({super.key, this.announcementId});

  final int? announcementId;

  bool get isEditing => announcementId != null;

  @override
  ConsumerState<AnnouncementEditPage> createState() =>
      _AnnouncementEditPageState();
}

class _AnnouncementEditPageState extends ConsumerState<AnnouncementEditPage> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  String _status = 'draft';
  String _notifyMode = 'silent';
  DateTime? _startsAt;
  DateTime? _endsAt;

  bool _custom = false;
  final List<_OrGroupDraft> _orGroups = [];
  int _condSeq = 0;

  bool _loadingDetail = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) _load();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loadingDetail = true);
    try {
      final a = await ref
          .read(adminAnnouncementsApiProvider)
          .getById(widget.announcementId!);
      if (!mounted) return;
      _titleCtrl.text = a.title;
      _contentCtrl.text = a.content;
      _status = a.status;
      _notifyMode = a.notifyMode;
      _startsAt = _parse(a.startsAt);
      _endsAt = _parse(a.endsAt);
      _custom = !a.targeting.isAll;
      _orGroups.clear();
      for (final g in a.targeting.anyOf) {
        _orGroups.add(_OrGroupDraft(conds: [
          for (final c in g.allOf)
            _CondDraft(
              id: _condSeq++,
              type: c.type,
              operator: c.operator,
              groupIds: c.groupIds.toSet(),
              value: c.value,
            ),
        ]));
      }
      setState(() => _loadingDetail = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingDetail = false);
      showAppToast(context, '$e', error: true);
    }
  }

  DateTime? _parse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  @override
  Widget build(BuildContext context) {
    final groups = (ref.watch(adminGroupsFullProvider).value ?? const [])
        .where((g) => g.subscriptionType == 'subscription')
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr(widget.isEditing
            ? 'adminAnnouncements.editTitle'
            : 'adminAnnouncements.createTitle')),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(context.tr('common.save')),
          ),
        ],
      ),
      body: _loadingDetail
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                TextField(
                  controller: _titleCtrl,
                  decoration: InputDecoration(
                    labelText: context.tr('adminAnnouncements.formTitle'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _contentCtrl,
                  maxLines: 6,
                  decoration: InputDecoration(
                    labelText: context.tr('adminAnnouncements.formContent'),
                    alignLabelWithHint: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                _dropdownRow(context, groups),
                const SizedBox(height: 16),
                _dateField(
                  label: context.tr('adminAnnouncements.startsAt'),
                  hint: context.tr('adminAnnouncements.immediate'),
                  value: _startsAt,
                  onPick: (d) => setState(() => _startsAt = d),
                ),
                const SizedBox(height: 12),
                _dateField(
                  label: context.tr('adminAnnouncements.endsAt'),
                  hint: context.tr('adminAnnouncements.never'),
                  value: _endsAt,
                  onPick: (d) => setState(() => _endsAt = d),
                ),
                const SizedBox(height: 20),
                _targetingEditor(context, groups),
              ],
            ),
    );
  }

  Widget _dropdownRow(BuildContext context, List<AdminGroup> groups) {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: _status,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: context.tr('adminAnnouncements.formStatus'),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              for (final s in ['draft', 'active', 'archived'])
                DropdownMenuItem(
                    value: s,
                    child: Text(context.tr('adminAnnouncements.status_$s'))),
            ],
            onChanged: (v) => setState(() => _status = v ?? 'draft'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: _notifyMode,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: context.tr('adminAnnouncements.formNotifyMode'),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              for (final m in ['silent', 'popup'])
                DropdownMenuItem(
                    value: m,
                    child: Text(context.tr('adminAnnouncements.notify_$m'))),
            ],
            onChanged: (v) => setState(() => _notifyMode = v ?? 'silent'),
          ),
        ),
      ],
    );
  }

  Widget _dateField({
    required String label,
    required String hint,
    required DateTime? value,
    required ValueChanged<DateTime?> onPick,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () async {
        final picked = await _pickDateTime(value);
        if (picked != null) onPick(picked.value);
      },
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: value != null
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => onPick(null),
                )
              : const Icon(Icons.event, size: 18),
        ),
        child: Text(
          value == null ? hint : formatDateTime(value),
          style: value == null
              ? TextStyle(color: scheme.onSurfaceVariant)
              : null,
        ),
      ),
    );
  }

  /// 返回一个包裹值,便于区分「取消(null)」与「选了时间」。
  Future<({DateTime? value})?> _pickDateTime(DateTime? initial) async {
    final base = initial ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (!mounted) return null;
    final t = time ?? TimeOfDay.fromDateTime(base);
    return (value: DateTime(date.year, date.month, date.day, t.hour, t.minute));
  }

  // ===== 受众定向编辑器 =====
  Widget _targetingEditor(BuildContext context, List<AdminGroup> groups) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('adminAnnouncements.targeting'),
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            _custom
                ? context.tr('adminAnnouncements.targetCustomHint')
                : context.tr('adminAnnouncements.targetAllHint'),
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                  value: false,
                  label: Text(context.tr('adminAnnouncements.targetAll'))),
              ButtonSegment(
                  value: true,
                  label: Text(context.tr('adminAnnouncements.targetCustomLabel'))),
            ],
            selected: {_custom},
            onSelectionChanged: (s) {
              setState(() {
                _custom = s.first;
                if (_custom && _orGroups.isEmpty) _addOrGroup();
                if (!_custom) _orGroups.clear();
              });
            },
          ),
          if (_custom) ...[
            const SizedBox(height: 12),
            for (var gi = 0; gi < _orGroups.length; gi++) ...[
              _orGroupCard(context, gi, groups),
              const SizedBox(height: 10),
            ],
            OutlinedButton.icon(
              onPressed: _orGroups.length >= 50 ? null : () => setState(_addOrGroup),
              icon: const Icon(Icons.add, size: 18),
              label: Text(context.tr('adminAnnouncements.addOrGroup')),
            ),
          ],
        ],
      ),
    );
  }

  void _addOrGroup() {
    _orGroups.add(_OrGroupDraft(conds: [_CondDraft(id: _condSeq++)]));
  }

  Widget _orGroupCard(BuildContext context, int gi, List<AdminGroup> groups) {
    final scheme = Theme.of(context).colorScheme;
    final group = _orGroups[gi];
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${context.tr('adminAnnouncements.conditionGroup')} #${gi + 1}  ·  ${context.tr('adminAnnouncements.matchAll')}',
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, size: 20, color: scheme.error),
                onPressed: () => setState(() => _orGroups.removeAt(gi)),
              ),
            ],
          ),
          for (var ci = 0; ci < group.conds.length; ci++) ...[
            const SizedBox(height: 6),
            _condCard(context, group, ci, groups),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: group.conds.length >= 50
                  ? null
                  : () => setState(
                      () => group.conds.add(_CondDraft(id: _condSeq++))),
              icon: const Icon(Icons.add, size: 18),
              label: Text(context.tr('adminAnnouncements.addCondition')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _condCard(BuildContext context, _OrGroupDraft group, int ci,
      List<AdminGroup> groups) {
    final scheme = Theme.of(context).colorScheme;
    final cond = group.conds[ci];
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: cond.type,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: context.tr('adminAnnouncements.conditionType'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    DropdownMenuItem(
                        value: 'subscription',
                        child: Text(
                            context.tr('adminAnnouncements.condSubscription'))),
                    DropdownMenuItem(
                        value: 'balance',
                        child:
                            Text(context.tr('adminAnnouncements.condBalance'))),
                  ],
                  onChanged: (v) => setState(() {
                    cond.type = v ?? 'subscription';
                    if (cond.type == 'subscription') {
                      cond.operator = 'in';
                    } else {
                      cond.operator = 'gte';
                      cond.value ??= 0;
                    }
                  }),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, size: 18, color: scheme.error),
                onPressed: () => setState(() => group.conds.removeAt(ci)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (cond.type == 'subscription')
            _groupChips(context, cond, groups)
          else
            _balanceFields(context, cond),
        ],
      ),
    );
  }

  Widget _groupChips(
      BuildContext context, _CondDraft cond, List<AdminGroup> groups) {
    if (groups.isEmpty) {
      return Text(context.tr('adminAnnouncements.noSubscriptionGroups'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant));
    }
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final g in groups)
          FilterChip(
            label: Text(g.name),
            selected: cond.groupIds.contains(g.id),
            onSelected: (sel) => setState(() {
              if (sel) {
                cond.groupIds.add(g.id);
              } else {
                cond.groupIds.remove(g.id);
              }
            }),
          ),
      ],
    );
  }

  Widget _balanceFields(BuildContext context, _CondDraft cond) {
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: DropdownButtonFormField<String>(
            initialValue: cond.operator == 'in' ? 'gte' : cond.operator,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: context.tr('adminAnnouncements.operator'),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              for (final op in ['gt', 'gte', 'lt', 'lte', 'eq'])
                DropdownMenuItem(
                    value: op,
                    child: Text(context.tr('adminAnnouncements.op_$op'))),
            ],
            onChanged: (v) => cond.operator = v ?? 'gte',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextFormField(
            key: ValueKey('cond-${cond.id}-value'),
            initialValue: cond.value == null ? '' : '${cond.value}',
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: context.tr('adminAnnouncements.balanceValue'),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => cond.value = num.tryParse(v.trim()) ?? 0,
          ),
        ),
      ],
    );
  }

  // ===== 保存 =====
  AnnouncementTargeting _buildTargeting() {
    if (!_custom) return const AnnouncementTargeting(anyOf: []);
    return AnnouncementTargeting(anyOf: [
      for (final g in _orGroups)
        AnnouncementConditionGroup(allOf: [
          for (final c in g.conds)
            AnnouncementCondition(
              type: c.type,
              operator: c.type == 'subscription' ? 'in' : c.operator,
              groupIds: c.groupIds.toList(),
              value: c.value,
            ),
        ]),
    ]);
  }

  String? _validate() {
    if (_titleCtrl.text.trim().isEmpty) {
      return context.tr('adminAnnouncements.errTitle');
    }
    if (_contentCtrl.text.trim().isEmpty) {
      return context.tr('adminAnnouncements.errContent');
    }
    if (_custom) {
      if (_orGroups.isEmpty) return context.tr('adminAnnouncements.errNoGroup');
      for (final g in _orGroups) {
        if (g.conds.isEmpty) {
          return context.tr('adminAnnouncements.errNoCondition');
        }
        for (final c in g.conds) {
          if (c.type == 'subscription' && c.groupIds.isEmpty) {
            return context.tr('adminAnnouncements.errNoPackage');
          }
        }
      }
    }
    return null;
  }

  Future<void> _save() async {
    final err = _validate();
    if (err != null) {
      showAppToast(context, err, error: true);
      return;
    }
    setState(() => _saving = true);
    final api = ref.read(adminAnnouncementsApiProvider);
    final targeting = _buildTargeting().toJson();
    int? unix(DateTime? d) => d == null ? null : d.millisecondsSinceEpoch ~/ 1000;
    try {
      if (widget.isEditing) {
        await api.update(widget.announcementId!, {
          'title': _titleCtrl.text.trim(),
          'content': _contentCtrl.text.trim(),
          'status': _status,
          'notify_mode': _notifyMode,
          'targeting': targeting,
          'starts_at': unix(_startsAt) ?? 0,
          'ends_at': unix(_endsAt) ?? 0,
        });
      } else {
        await api.create({
          'title': _titleCtrl.text.trim(),
          'content': _contentCtrl.text.trim(),
          'status': _status,
          'notify_mode': _notifyMode,
          'targeting': targeting,
          if (_startsAt != null) 'starts_at': unix(_startsAt),
          if (_endsAt != null) 'ends_at': unix(_endsAt),
        });
      }
      if (!mounted) return;
      showAppToast(context, context.tr('common.done'));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppToast(context, '$e', error: true);
    }
  }
}
