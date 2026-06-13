import 'package:flutter_test/flutter_test.dart';
import 'package:sub2api/src/features/user/usage_logs/data/usage_logs_api.dart';

void main() {
  test('UsageLog.fromJson uses total_cost as original billing amount', () {
    final log = UsageLog.fromJson({
      'id': 1,
      'user_id': 2,
      'api_key_id': 3,
      'request_id': 'req_123',
      'model': 'gpt-5',
      'group': {'name': 'pro', 'platform': 'openai'},
      'input_tokens': 10,
      'output_tokens': 20,
      'cache_creation_tokens': 3,
      'cache_read_tokens': 4,
      'cost': 0.42,
      'total_cost': 0.84,
      'actual_cost': 0.21,
      'extra_payload': {'visible': true},
    });

    expect(log.provider, 'openai');
    expect(log.totalTokenCount, 37);
    expect(log.standardCost, 0.84);
    expect(log.actualCost, 0.21);
    expect(log.rawJson['extra_payload'], {'visible': true});
  });
}
