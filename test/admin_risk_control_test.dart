import 'package:flutter_test/flutter_test.dart';
import 'package:sub2api/src/features/admin/riskcontrol/data/admin_risk_control_api.dart';

void main() {
  test('ContentModerationConfig.fromJson parses thresholds/model_filter/keys', () {
    final c = ContentModerationConfig.fromJson({
      'enabled': true,
      'mode': 'pre_block',
      'base_url': 'https://api.openai.com',
      'model': 'omni-moderation-latest',
      'api_key_configured': true,
      'api_key_count': 2,
      'api_key_masks': ['sk-a***', 'sk-b***'],
      'api_key_statuses': [
        {'index': 0, 'key_hash': 'h1', 'masked': 'sk-a***', 'status': 'ok'},
        {'index': 1, 'key_hash': 'h2', 'masked': 'sk-b***', 'status': 'frozen'},
      ],
      'timeout_ms': 3000,
      'sample_rate': 80,
      'all_groups': false,
      'group_ids': [1, 2, 3],
      'thresholds': {'hate': 0.65, 'violence': 0.95},
      'blocked_keywords': ['x', 'y'],
      'keyword_blocking_mode': 'keyword_only',
      'model_filter': {'type': 'include', 'models': ['gpt-4', 'gpt-4']},
    });
    expect(c.enabled, true);
    expect(c.apiKeyCount, 2);
    expect(c.apiKeyStatuses.length, 2);
    expect(c.apiKeyStatuses[1].status, 'frozen');
    expect(c.groupIds, [1, 2, 3]);
    expect(c.thresholds['hate'], 0.65);
    expect(c.blockedKeywords, ['x', 'y']);
    expect(c.keywordBlockingMode, 'keyword_only');
    expect(c.modelFilter.type, 'include');
    expect(c.modelFilter.models, ['gpt-4', 'gpt-4']);
  });

  test('ModelFilter all type drops models', () {
    final f = ModelFilter.fromJson({'type': 'all', 'models': ['gpt-4']});
    expect(f.type, 'all');
    expect(f.models, isEmpty);
    expect(f.toJson()['models'], isEmpty);
  });

  test('ModerationLog canUnban + copyWithUserStatus', () {
    final log = ModerationLog.fromJson({
      'id': 1,
      'user_id': 7,
      'auto_banned': true,
      'user_status': 'disabled',
      'flagged': true,
      'action': 'block',
      'highest_category': 'hate',
      'highest_score': 0.9,
      'category_scores': {'hate': 0.9},
      'threshold_snapshot': {'hate': 0.65},
    });
    expect(log.canUnban, true);
    final active = log.copyWithUserStatus('active');
    expect(active.userStatus, 'active');
    expect(active.canUnban, false);
    expect(active.id, 1);
    expect(active.categoryScores['hate'], 0.9);
  });

  test('ModerationLog not unbannable when not auto-banned', () {
    final log = ModerationLog.fromJson({
      'id': 2,
      'user_id': 7,
      'auto_banned': false,
      'user_status': 'disabled',
    });
    expect(log.canUnban, false);
  });

  test('ModerationLogsPage.fromJson', () {
    final p = ModerationLogsPage.fromJson({
      'items': [
        {'id': 1, 'action': 'block'},
        {'id': 2, 'action': 'pass'},
      ],
      'total': 2,
      'page': 1,
      'pages': 1,
    });
    expect(p.items.length, 2);
    expect(p.total, 2);
  });

  test('ContentModerationStatus.fromJson reads counters + loads', () {
    final s = ContentModerationStatus.fromJson({
      'enabled': true,
      'mode': 'pre_block',
      'worker_count': 4,
      'max_workers': 8,
      'active_workers': 1,
      'idle_workers': 3,
      'queue_size': 1000,
      'queue_length': 50,
      'queue_usage_percent': 5,
      'processed': 1234,
      'pre_block_checked': 100,
      'pre_block_blocked': 5,
      'pre_block_avg_latency_ms': 42.5,
      'pre_block_api_key_loads': [
        {'masked': 'sk-a***', 'status': 'ok', 'active': 1, 'total': 10}
      ],
      'flagged_hash_count': 9,
    });
    expect(s.workerCount, 4);
    expect(s.maxWorkers, 8);
    expect(s.queueLength, 50);
    expect(s.processed, 1234);
    expect(s.apiKeyLoads.single.masked, 'sk-a***');
    expect(s.flaggedHashCount, 9);
  });

  test('TestApiKeysResult.fromJson with audit', () {
    final r = TestApiKeysResult.fromJson({
      'items': [
        {'index': 0, 'masked': 'sk-a***', 'status': 'ok'}
      ],
      'audit_result': {
        'flagged': true,
        'highest_category': 'hate',
        'highest_score': 0.8,
        'composite_score': 0.7,
      },
    });
    expect(r.items.single.status, 'ok');
    expect(r.auditResult?.flagged, true);
    expect(r.auditResult?.highestCategory, 'hate');
  });
}
