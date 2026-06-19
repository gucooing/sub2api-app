import 'package:flutter_test/flutter_test.dart';
import 'package:sub2api/src/features/admin/usage/data/admin_usage_api.dart';

void main() {
  test('AdminUsageLog.fromJson parses nested user/group/account', () {
    final l = AdminUsageLog.fromJson({
      'id': 1,
      'user_id': 5,
      'model': 'claude-3-5-sonnet',
      'upstream_model': 'claude-3-5-sonnet-20241022',
      'user': {'email': 'a@b.com'},
      'api_key': {'name': 'key1'},
      'group': {'name': 'default'},
      'account': {'id': 2, 'name': 'acc1'},
      'input_tokens': 100,
      'output_tokens': 50,
      'cache_creation_tokens': 10,
      'cache_read_tokens': 5,
      'total_cost': 0.02,
      'actual_cost': 0.01,
      'account_stats_cost': 0.008,
      'account_rate_multiplier': 1.5,
      'stream': true,
    });
    expect(l.userEmail, 'a@b.com');
    expect(l.apiKeyName, 'key1');
    expect(l.groupName, 'default');
    expect(l.accountName, 'acc1');
    expect(l.totalTokens, 165);
    expect(l.resolvedType, 'stream');
    expect(l.accountCost, closeTo(0.008 * 1.5, 1e-9));
  });

  test('resolvedType prefers request_type, falls back to stream', () {
    const ws = AdminUsageLog(id: 1, userId: 1, model: 'm', requestType: 'ws_v2');
    expect(ws.resolvedType, 'ws_v2');
    const sync = AdminUsageLog(id: 1, userId: 1, model: 'm', stream: false);
    expect(sync.resolvedType, 'sync');
  });

  test('AdminUsageStats.fromJson', () {
    final s = AdminUsageStats.fromJson({
      'total_requests': 1000,
      'total_tokens': 5000000,
      'total_cost': 12.5,
      'total_actual_cost': 9.0,
      'total_account_cost': 7.0,
      'average_duration_ms': 1234,
    });
    expect(s.totalRequests, 1000);
    expect(s.totalTokens, 5000000);
    expect(s.totalActualCost, 9.0);
  });

  test('UsageCleanupTask.fromJson extracts filter time range', () {
    final t = UsageCleanupTask.fromJson({
      'id': 3,
      'status': 'completed',
      'deleted_rows': 4200,
      'filters': {
        'start_time': '2026-01-01T00:00:00Z',
        'end_time': '2026-02-01T00:00:00Z',
      },
    });
    expect(t.status, 'completed');
    expect(t.deletedRows, 4200);
    expect(t.startTime, '2026-01-01T00:00:00Z');
    expect(t.isActive, isFalse);
  });
}
