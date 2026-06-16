import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../../i18n/app_localizations.dart';
import '../../../../../shared/widgets/app_toast.dart';

/// Vertex Service Account 凭据值。
class ServiceAccountValue {
  ServiceAccountValue({
    this.projectId = '',
    this.clientEmail = '',
    this.location = 'us-central1',
    this.saJson, // 新上传的原始 JSON;null = 沿用已有
  });
  String projectId;
  String clientEmail;
  String location;
  String? saJson;

  factory ServiceAccountValue.fromCredentials(Map<String, dynamic> c) =>
      ServiceAccountValue(
        projectId: (c['project_id'] as String?) ?? '',
        clientEmail: (c['client_email'] as String?) ?? '',
        location: (c['location'] as String?) ??
            (c['vertex_location'] as String?) ??
            'us-central1',
      );

  void applyToCredentials(Map<String, dynamic> creds) {
    if (saJson != null && saJson!.isNotEmpty) {
      creds['service_account_json'] = saJson;
    }
    creds['project_id'] = projectId.trim();
    creds['client_email'] = clientEmail.trim();
    creds['location'] = location.trim();
    creds['tier_id'] = 'vertex';
  }
}

/// 常用 Vertex location(对照 web VERTEX_LOCATION_OPTIONS 的常用子集)。
const List<String> kVertexLocations = [
  'us-central1', 'global', 'us', 'eu',
  'us-east1', 'us-east4', 'us-east5', 'us-west1', 'us-west4',
  'europe-west1', 'europe-west2', 'europe-west3', 'europe-west4',
  'asia-east1', 'asia-northeast1', 'asia-northeast3', 'asia-south1',
  'asia-southeast1', 'australia-southeast1',
];

/// Vertex Service Account 凭据区块。
class ServiceAccountSection extends StatefulWidget {
  const ServiceAccountSection({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.isEdit = false,
    this.hasExistingJson = false,
  });

  final ServiceAccountValue value;
  final ValueChanged<ServiceAccountValue> onChanged;
  final bool enabled;
  final bool isEdit;
  final bool hasExistingJson;

  @override
  State<ServiceAccountSection> createState() => _ServiceAccountSectionState();
}

class _ServiceAccountSectionState extends State<ServiceAccountSection> {
  late ServiceAccountValue _v;
  String? _fileName;

  @override
  void initState() {
    super.initState();
    _v = widget.value;
  }

  void _emit() => widget.onChanged(_v);

  Future<void> _pick() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    final file = res?.files.single;
    if (file == null) return;
    try {
      final bytes = file.bytes;
      final raw = bytes != null ? utf8.decode(bytes) : '';
      final obj = jsonDecode(raw);
      if (obj is! Map) throw const FormatException('not an object');
      setState(() {
        _v.saJson = raw;
        _v.projectId = (obj['project_id'] as String?) ?? _v.projectId;
        _v.clientEmail = (obj['client_email'] as String?) ?? _v.clientEmail;
        _fileName = file.name;
      });
      _emit();
    } catch (_) {
      if (mounted) {
        showAppToast(context, context.tr('adminAccounts.sa.invalidJson'),
            error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: widget.enabled ? _pick : null,
          icon: const Icon(Icons.upload_file, size: 18),
          label: Text(context.tr('adminAccounts.sa.uploadJson')),
        ),
        const SizedBox(height: 4),
        Text(
          _fileName ??
              (widget.hasExistingJson
                  ? context.tr('adminAccounts.sa.jsonOnFile')
                  : context.tr('adminAccounts.sa.noJson')),
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        TextField(
          enabled: false,
          controller: TextEditingController(text: _v.projectId),
          decoration: const InputDecoration(
            labelText: 'Project ID',
            isDense: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue:
              kVertexLocations.contains(_v.location) ? _v.location : 'us-central1',
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Location',
            isDense: true,
            border: OutlineInputBorder(),
          ),
          items: [
            for (final l in kVertexLocations)
              DropdownMenuItem(value: l, child: Text(l)),
          ],
          onChanged: widget.enabled
              ? (v) {
                  setState(() => _v.location = v ?? 'us-central1');
                  _emit();
                }
              : null,
        ),
      ],
    );
  }
}
