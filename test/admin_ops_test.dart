import 'package:flutter_test/flutter_test.dart';
import 'package:sub2api/src/features/admin/ops/data/admin_ops_api.dart';

void main() {
  test('OpsOverview.fromJson reads nested qps/tps + percentiles', () {
    final o = OpsOverview.fromJson({
      'health_score': 92,
      'success_count': 980,
      'error_count_total': 20,
      'request_count_total': 1000,
      'token_consumed': 123456,
      'sla': 0.98,
      'error_rate': 0.02,
      'upstream_error_rate': 0.01,
      'upstream_429_count': 3,
      'upstream_529_count': 1,
      'qps': {'current': 5.5, 'peak': 12.0, 'avg': 6.0},
      'tps': {'current': 100.0, 'peak': 250.0},
      'duration': {'p50_ms': 120, 'p95_ms': 800, 'p99_ms': 1500},
      'ttft': {'p95_ms': 300, 'p99_ms': 600},
    });
    expect(o.healthScore, 92);
    expect(o.successCount, 980);
    expect(o.sla, 0.98);
    expect(o.qpsCurrent, 5.5);
    expect(o.qpsPeak, 12.0);
    expect(o.tpsPeak, 250.0);
    expect(o.duration.p95, 800);
    expect(o.ttft.p99, 600);
    expect(o.upstream429Count, 3);
  });

  test('OpsErrorLog.fromJson', () {
    final e = OpsErrorLog.fromJson({
      'id': 5,
      'created_at': '2026-06-20T00:00:00Z',
      'phase': 'upstream',
      'type': 'timeout',
      'error_owner': 'provider',
      'error_source': 'upstream_http',
      'severity': 'warning',
      'status_code': 504,
      'platform': 'anthropic',
      'model': 'claude',
      'resolved': false,
      'request_id': 'req-1',
      'message': 'gateway timeout',
      'user_email': 'u@x.com',
      'account_name': 'acc',
      'group_name': 'grp',
    });
    expect(e.id, 5);
    expect(e.statusCode, 504);
    expect(e.severity, 'warning');
    expect(e.resolved, false);
    expect(e.message, 'gateway timeout');
  });

  test('OpsErrorDetail.fromJson wraps log + body/latency', () {
    final d = OpsErrorDetail.fromJson({
      'id': 9,
      'status_code': 500,
      'message': 'boom',
      'error_body': '{"error":"x"}',
      'user_agent': 'curl',
      'client_ip': '1.2.3.4',
      'upstream_status_code': 502,
      'upstream_latency_ms': 1200,
      'time_to_first_token_ms': 300,
    });
    expect(d.log.id, 9);
    expect(d.log.statusCode, 500);
    expect(d.errorBody, '{"error":"x"}');
    expect(d.clientIp, '1.2.3.4');
    expect(d.upstreamStatusCode, 502);
    expect(d.timeToFirstTokenMs, 300);
  });

  test('OpsSystemLog.fromJson', () {
    final l = OpsSystemLog.fromJson({
      'id': 1,
      'created_at': '2026-06-20T00:00:00Z',
      'level': 'error',
      'component': 'scheduler',
      'message': 'job failed',
      'request_id': 'r1',
    });
    expect(l.level, 'error');
    expect(l.component, 'scheduler');
    expect(l.message, 'job failed');
  });

  test('AlertRule.fromJson', () {
    final r = AlertRule.fromJson({
      'id': 2,
      'name': 'High error rate',
      'enabled': true,
      'metric_type': 'error_rate',
      'operator': '>',
      'threshold': 0.05,
      'window_minutes': 5,
      'severity': 'critical',
      'notify_email': true,
    });
    expect(r.name, 'High error rate');
    expect(r.enabled, true);
    expect(r.operator, '>');
    expect(r.threshold, 0.05);
    expect(r.severity, 'critical');
  });

  test('AlertEvent.fromJson + isFiring', () {
    final firing = AlertEvent.fromJson({
      'id': 1,
      'rule_id': 2,
      'severity': 'critical',
      'status': 'firing',
      'fired_at': '2026-06-20T00:00:00Z',
      'email_sent': true,
      'metric_value': 0.1,
      'threshold_value': 0.05,
    });
    expect(firing.isFiring, true);
    expect(firing.metricValue, 0.1);

    final resolved = AlertEvent.fromJson({
      'id': 2,
      'rule_id': 2,
      'status': 'resolved',
      'fired_at': '',
      'email_sent': false,
    });
    expect(resolved.isFiring, false);
  });

  test('OpsPage.parse generic pagination', () {
    final p = OpsPage.parse({
      'items': [
        {'id': 1, 'level': 'info', 'component': 'a', 'message': 'm1'},
        {'id': 2, 'level': 'warn', 'component': 'b', 'message': 'm2'},
      ],
      'total': 2,
      'page': 1,
      'pages': 1,
    }, OpsSystemLog.fromJson);
    expect(p.items.length, 2);
    expect(p.items.first.component, 'a');
    expect(p.total, 2);
  });
}
