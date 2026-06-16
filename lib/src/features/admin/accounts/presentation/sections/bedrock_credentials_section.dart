import 'package:flutter/material.dart';

import '../../../../../i18n/app_localizations.dart';
import '../../../../../shared/widgets/pill_segmented.dart';

/// Bedrock 凭据值(SigV4 或 APIKey 模式 + 区域 + 强制 global)。
class BedrockCredsValue {
  BedrockCredsValue({
    this.authMode = 'sigv4', // sigv4 / apikey
    this.accessKeyId = '',
    this.secretKey = '',
    this.sessionToken = '',
    this.apiKey = '',
    this.region = '',
    this.forceGlobal = false,
  });
  String authMode;
  String accessKeyId;
  String secretKey;
  String sessionToken;
  String apiKey;
  String region;
  bool forceGlobal;

  factory BedrockCredsValue.fromCredentials(Map<String, dynamic> c) =>
      BedrockCredsValue(
        authMode: (c['auth_mode'] as String?) ?? 'sigv4',
        accessKeyId: (c['aws_access_key_id'] as String?) ?? '',
        region: (c['aws_region'] as String?) ?? '',
        forceGlobal: (c['aws_force_global'] as String?) == 'true',
      );

  /// 写入 credentials(敏感键留空保留已有)。
  void applyToCredentials(Map<String, dynamic> creds) {
    creds['auth_mode'] = authMode;
    creds['aws_region'] = region.trim();
    if (forceGlobal) {
      creds['aws_force_global'] = 'true';
    } else {
      creds.remove('aws_force_global');
    }
    if (authMode == 'apikey') {
      if (apiKey.trim().isNotEmpty) creds['api_key'] = apiKey.trim();
    } else {
      creds['aws_access_key_id'] = accessKeyId.trim();
      if (secretKey.trim().isNotEmpty) {
        creds['aws_secret_access_key'] = secretKey.trim();
      }
      if (sessionToken.trim().isNotEmpty) {
        creds['aws_session_token'] = sessionToken.trim();
      }
    }
  }
}

/// Bedrock 凭据区块。
class BedrockCredentialsSection extends StatefulWidget {
  const BedrockCredentialsSection({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.isEdit = false,
  });

  final BedrockCredsValue value;
  final ValueChanged<BedrockCredsValue> onChanged;
  final bool enabled;
  final bool isEdit;

  @override
  State<BedrockCredentialsSection> createState() =>
      _BedrockCredentialsSectionState();
}

class _BedrockCredentialsSectionState extends State<BedrockCredentialsSection> {
  late BedrockCredsValue _v;
  final _accessKey = TextEditingController();
  final _secret = TextEditingController();
  final _session = TextEditingController();
  final _apiKey = TextEditingController();
  final _region = TextEditingController();

  @override
  void initState() {
    super.initState();
    _v = widget.value;
    _accessKey.text = _v.accessKeyId;
    _region.text = _v.region;
  }

  @override
  void dispose() {
    for (final c in [_accessKey, _secret, _session, _apiKey, _region]) {
      c.dispose();
    }
    super.dispose();
  }

  void _emit() => widget.onChanged(_v);

  InputDecoration _dec(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        border: const OutlineInputBorder(),
      );

  @override
  Widget build(BuildContext context) {
    final keepHint = context.tr('adminAccounts.bedrock.leaveEmptyKeep');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: PillSegmented<String>(
            selected: _v.authMode,
            onChanged: widget.enabled
                ? (m) => setState(() {
                      _v.authMode = m;
                      _emit();
                    })
                : (_) {},
            options: [
              ('sigv4', context.tr('adminAccounts.bedrock.sigv4')),
              ('apikey', context.tr('adminAccounts.bedrock.apiKeyMode')),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_v.authMode == 'apikey')
          TextField(
            controller: _apiKey,
            enabled: widget.enabled,
            obscureText: true,
            decoration: _dec(context.tr('adminAccounts.bedrock.apiKey'),
                hint: widget.isEdit ? keepHint : null),
            onChanged: (t) {
              _v.apiKey = t;
              _emit();
            },
          )
        else ...[
          TextField(
            controller: _accessKey,
            enabled: widget.enabled,
            decoration: _dec(context.tr('adminAccounts.bedrock.accessKeyId'),
                hint: 'AKIA...'),
            onChanged: (t) {
              _v.accessKeyId = t;
              _emit();
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _secret,
            enabled: widget.enabled,
            obscureText: true,
            decoration: _dec(context.tr('adminAccounts.bedrock.secretKey'),
                hint: widget.isEdit ? keepHint : null),
            onChanged: (t) {
              _v.secretKey = t;
              _emit();
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _session,
            enabled: widget.enabled,
            obscureText: true,
            decoration: _dec(context.tr('adminAccounts.bedrock.sessionToken'),
                hint: widget.isEdit ? keepHint : null),
            onChanged: (t) {
              _v.sessionToken = t;
              _emit();
            },
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _region,
          enabled: widget.enabled,
          decoration: _dec(context.tr('adminAccounts.bedrock.region'),
              hint: 'us-east-1'),
          onChanged: (t) {
            _v.region = t;
            _emit();
          },
        ),
        const SizedBox(height: 4),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          dense: true,
          value: _v.forceGlobal,
          title: Text(context.tr('adminAccounts.bedrock.forceGlobal')),
          subtitle: Text(context.tr('adminAccounts.bedrock.forceGlobalHint')),
          onChanged: widget.enabled
              ? (b) => setState(() {
                    _v.forceGlobal = b ?? false;
                    _emit();
                  })
              : null,
        ),
      ],
    );
  }
}
