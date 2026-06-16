import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../i18n/app_localizations.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_retry.dart';
import '../../../../shared/widgets/responsive.dart';
import '../data/admin_groups_api.dart';
import '../providers/admin_groups_providers.dart';

/// 分组内用户专属倍率 / RPM 覆盖编辑(批量保存)。
class GroupRatesPage extends ConsumerStatefulWidget {
  const GroupRatesPage({super.key, required this.groupId});
  final int groupId;

  @override
  ConsumerState<GroupRatesPage> createState() => _GroupRatesPageState();
}

class _GroupRatesPageState extends ConsumerState<GroupRatesPage> {
  final Map<int, TextEditingController> _rate = {};
  final Map<int, TextEditingController> _rpm = {};
  bool _saving = false;
  bool _seeded = false;

  @override
  void dispose() {
    for (final c in _rate.values) {
      c.dispose();
    }
    for (final c in _rpm.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _seed(List<GroupRateEntry> entries) {
    if (_seeded) return;
    _seeded = true;
    for (final e in entries) {
      _rate[e.userId] = TextEditingController(
          text: e.rateMultiplier == null ? '' : '${e.rateMultiplier}');
      _rpm[e.userId] = TextEditingController(
          text: e.rpmOverride == null ? '' : '${e.rpmOverride}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(adminGroupRatesProvider(widget.groupId));
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('adminGroups.rateEditor'))),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorRetryView(
          error: e,
          onRetry: () => ref.invalidate(adminGroupRatesProvider(widget.groupId)),
        ),
        data: (entries) {
          if (entries.isEmpty) {
            return EmptyState(
              icon: Icons.people_outline,
              message: context.tr('adminGroups.noMembers'),
            );
          }
          _seed(entries);
          return Column(
            children: [
              Expanded(
                child: ResponsiveCenter(
                  maxWidth: 720,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: entries.length,
                    itemBuilder: (context, i) => _row(entries[i]),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : _clearAll,
                        child: Text(context.tr('adminGroups.clearAll')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : Text(context.tr('common.save')),
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _row(GroupRateEntry e) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(e.userName.isEmpty ? e.userEmail : e.userName,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
            if (e.userName.isNotEmpty)
              Text(e.userEmail,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _rate[e.userId],
                  enabled: !_saving,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: context.tr('adminGroups.rateMultiplier'),
                    hintText: context.tr('adminGroups.inherit'),
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _rpm[e.userId],
                  enabled: !_saving,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: context.tr('adminGroups.rpmOverride'),
                    hintText: context.tr('adminGroups.inherit'),
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final api = ref.read(adminGroupsApiProvider);
    try {
      final rates = <({int userId, num rateMultiplier})>[];
      _rate.forEach((uid, c) {
        final v = num.tryParse(c.text.trim());
        if (v != null) rates.add((userId: uid, rateMultiplier: v));
      });
      final rpms = <({int userId, int rpmOverride})>[];
      _rpm.forEach((uid, c) {
        final v = int.tryParse(c.text.trim());
        if (v != null) rpms.add((userId: uid, rpmOverride: v));
      });
      if (rates.isNotEmpty) await api.setRateMultipliers(widget.groupId, rates);
      if (rpms.isNotEmpty) await api.setRpmOverrides(widget.groupId, rpms);
      ref.invalidate(adminGroupRatesProvider(widget.groupId));
      if (mounted) showAppToast(context, context.tr('common.done'));
    } catch (e) {
      if (mounted) showAppToast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _clearAll() async {
    setState(() => _saving = true);
    final api = ref.read(adminGroupsApiProvider);
    try {
      await api.clearRateMultipliers(widget.groupId);
      await api.clearRpmOverrides(widget.groupId);
      for (final c in _rate.values) {
        c.clear();
      }
      for (final c in _rpm.values) {
        c.clear();
      }
      ref.invalidate(adminGroupRatesProvider(widget.groupId));
      if (mounted) showAppToast(context, context.tr('common.done'));
    } catch (e) {
      if (mounted) showAppToast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
