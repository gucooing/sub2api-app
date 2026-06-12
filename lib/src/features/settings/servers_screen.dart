import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/server/server_profile.dart';
import '../../core/server/server_store.dart';
import '../../i18n/app_localizations.dart';

/// 服务器管理页:列表选择激活后端、添加/编辑/删除。
/// 登录前后均可进入;切换激活服务器后会话层自动针对新后端恢复登录态。
class ServersScreen extends ConsumerWidget {
  const ServersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(serverStoreProvider);
    final store = ref.read(serverStoreProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('servers.title'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditDialog(context, store),
        icon: const Icon(Icons.add),
        label: Text(context.tr('servers.add')),
      ),
      body: RadioGroup<String>(
        groupValue: state.activeId,
        onChanged: (id) {
          if (id != null) store.setActive(id);
        },
        child: ListView.separated(
          padding: const EdgeInsets.only(bottom: 88),
          itemCount: state.servers.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final server = state.servers[index];
            final isActive = server.id == state.activeId;
            return RadioListTile<String>(
              value: server.id,
              title: Row(
                children: [
                  Flexible(child: Text(server.name)),
                  if (server.builtIn) ...[
                    const SizedBox(width: 8),
                    _Tag(text: context.tr('servers.builtinTag')),
                  ],
                ],
              ),
              subtitle: Text(server.baseUrl),
              secondary: MenuAnchor(
                builder: (context, controller, _) => IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () =>
                      controller.isOpen ? controller.close() : controller.open(),
                ),
                menuChildren: [
                  MenuItemButton(
                    leadingIcon: const Icon(Icons.edit_outlined),
                    onPressed: () =>
                        _showEditDialog(context, store, server: server),
                    child: Text(context.tr('common.edit')),
                  ),
                  MenuItemButton(
                    leadingIcon: const Icon(Icons.delete_outline),
                    onPressed: (server.builtIn || isActive)
                        ? null
                        : () => _confirmDelete(context, store, server),
                    child: Text(context.tr('common.delete')),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _showEditDialog(BuildContext context, ServerStore store,
      {ServerProfile? server}) async {
    final nameController = TextEditingController(text: server?.name ?? '');
    final urlController = TextEditingController(text: server?.baseUrl ?? '');
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(server == null
            ? context.tr('servers.add')
            : context.tr('servers.edit')),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: context.tr('servers.name'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: urlController,
                enabled: !(server?.builtIn ?? false),
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: context.tr('servers.address'),
                  hintText: 'https://api.example.com',
                  border: const OutlineInputBorder(),
                ),
                validator: (v) =>
                    ServerProfile.normalizeBaseUrl(v ?? '') == null
                        ? context.tr('servers.invalidAddress')
                        : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.tr('common.cancel')),
          ),
          FilledButton(
            onPressed: () async {
              if (!(server?.builtIn ?? false) &&
                  !formKey.currentState!.validate()) {
                return;
              }
              if (server == null) {
                await store.add(nameController.text, urlController.text);
              } else {
                await store.update(
                  server.id,
                  name: nameController.text,
                  baseUrl: server.builtIn ? null : urlController.text,
                );
              }
              if (context.mounted) Navigator.of(context).pop();
            },
            child: Text(context.tr('common.save')),
          ),
        ],
      ),
    );
    nameController.dispose();
    urlController.dispose();
  }

  Future<void> _confirmDelete(
      BuildContext context, ServerStore store, ServerProfile server) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('common.delete')),
        content: Text(context
            .tr('servers.deleteConfirm', params: {'name': server.name})),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('common.cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.tr('common.delete')),
          ),
        ],
      ),
    );
    if (confirmed == true) await store.remove(server.id);
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: scheme.onSecondaryContainer),
      ),
    );
  }
}
