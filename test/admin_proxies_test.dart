import 'package:flutter_test/flutter_test.dart';
import 'package:sub2api/src/features/admin/proxies/data/admin_proxies_api.dart';

void main() {
  test('Proxy.fromJson + endpoint + location', () {
    final p = Proxy.fromJson({
      'id': 1,
      'name': 'us-proxy',
      'protocol': 'socks5',
      'host': '1.2.3.4',
      'port': 1080,
      'username': 'u',
      'status': 'active',
      'account_count': 3,
      'latency_ms': 120,
      'city': 'NYC',
      'region': 'NY',
      'country': 'US',
      'quality_grade': 'A',
      'fallback_mode': 'proxy',
      'backup_proxy_id': 5,
    });
    expect(p.endpoint, 'socks5://1.2.3.4:1080');
    expect(p.location, 'NYC, NY, US');
    expect(p.accountCount, 3);
    expect(p.backupProxyId, 5);
    expect(p.fallbackMode, 'proxy');
  });

  test('ProxyTestResult.fromJson', () {
    final r = ProxyTestResult.fromJson({
      'success': true,
      'message': 'ok',
      'latency_ms': 88,
      'ip_address': '9.9.9.9',
      'country': 'JP',
    });
    expect(r.success, isTrue);
    expect(r.latencyMs, 88);
    expect(r.country, 'JP');
  });

  test('ProxyQualityResult.fromJson with items', () {
    final q = ProxyQualityResult.fromJson({
      'proxy_id': 1,
      'score': 85,
      'grade': 'A',
      'summary': 'good',
      'passed_count': 4,
      'warn_count': 1,
      'failed_count': 0,
      'challenge_count': 0,
      'items': [
        {'target': 'anthropic', 'status': 'pass', 'http_status': 200, 'latency_ms': 100},
        {'target': 'openai', 'status': 'warn', 'message': 'slow'},
      ],
    });
    expect(q.score, 85);
    expect(q.grade, 'A');
    expect(q.items.length, 2);
    expect(q.items.first.status, 'pass');
    expect(q.passedCount, 4);
  });

  test('ProxyPage.fromJson', () {
    final pg = ProxyPage.fromJson({
      'items': [
        {'id': 1, 'name': 'a', 'host': 'h', 'port': 80},
      ],
      'total': 1,
      'page': 1,
      'pages': 1,
    });
    expect(pg.items.length, 1);
    expect(pg.items.first.protocol, 'http');
  });
}
