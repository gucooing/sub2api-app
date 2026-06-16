import 'package:flutter_test/flutter_test.dart';
import 'package:sub2api/src/features/admin/monitor/data/admin_monitor_api.dart';

void main() {
  test('ChannelMonitor.fromJson 解析 + extra_models_status', () {
    final m = ChannelMonitor.fromJson({
      'id': 4,
      'name': 'prod-openai',
      'provider': 'openai',
      'endpoint': 'https://api.openai.com',
      'primary_model': 'gpt-4o',
      'enabled': false,
      'interval_seconds': 300,
      'primary_status': 'degraded',
      'primary_latency_ms': 820,
      'availability_7d': 99.2,
      'extra_models': ['gpt-4o-mini'],
      'extra_models_status': [
        {'model': 'gpt-4o-mini', 'status': 'operational', 'latency_ms': 300},
      ],
    });
    expect(m.name, 'prod-openai');
    expect(m.enabled, isFalse);
    expect(m.primaryStatus, 'degraded');
    expect(m.availability7d, 99.2);
    expect(m.extraModelsStatus.single.model, 'gpt-4o-mini');
    expect(m.extraModelsStatus.single.status, 'operational');
  });

  test('ChannelMonitorPage.fromJson', () {
    final p = ChannelMonitorPage.fromJson({
      'items': [
        {'id': 1, 'name': 'a'},
      ],
      'total': 1,
      'page': 1,
      'pages': 1,
    });
    expect(p.items.single.apiMode, 'chat_completions');
    expect(p.total, 1);
  });

  test('MonitorCheckItem.fromJson', () {
    final c = MonitorCheckItem.fromJson({
      'model': 'gpt-4o',
      'status': 'failed',
      'latency_ms': null,
      'ping_latency_ms': 40,
      'message': 'timeout',
      'checked_at': '2026-06-16T10:00:00Z',
    });
    expect(c.status, 'failed');
    expect(c.latencyMs, isNull);
    expect(c.pingLatencyMs, 40);
    expect(c.message, 'timeout');
  });
}
