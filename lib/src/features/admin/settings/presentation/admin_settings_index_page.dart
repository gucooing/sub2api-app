import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../i18n/app_localizations.dart';
import '../../../../shared/widgets/responsive.dart';
import '../data/admin_setting_fields.dart';

/// 系统设置首页:大类列表(对照 web 标签),点击进入各类设置页。
class AdminSettingsIndexPage extends ConsumerWidget {
  const AdminSettingsIndexPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('admin.settings.title'))),
      body: ResponsiveCenter(
        maxWidth: 640,
        child: ListView(
          children: [
            for (final c in kSettingCategories)
              ListTile(
                leading: Icon(c.icon),
                title: Text(context.tr(c.labelKey)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/admin/settings/${c.key}'),
              ),
          ],
        ),
      ),
    );
  }
}
