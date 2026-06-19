import 'package:flutter_test/flutter_test.dart';
import 'package:sub2api/src/features/admin/channels/data/admin_channels_api.dart';

void main() {
  test('Channel.fromJson parses pricing + preserves raw', () {
    final c = Channel.fromJson({
      'id': 1,
      'name': 'Default',
      'description': 'desc',
      'status': 'active',
      'billing_model_source': 'upstream',
      'restrict_models': true,
      'apply_pricing_to_account_stats': true,
      'group_ids': [1, 2],
      'model_pricing': [
        {
          'platform': 'anthropic',
          'models': ['claude-3-5-sonnet'],
          'billing_mode': 'token',
          'input_price': 0.000003,
          'output_price': 0.000015,
          'intervals': [
            {'min_tokens': 0, 'max_tokens': 1000, 'tier_label': 't1'}
          ],
        }
      ],
      'model_mapping': {'anthropic': {'a': 'b'}},
      'account_stats_pricing_rules': [{'name': 'r1'}],
    });
    expect(c.name, 'Default');
    expect(c.billingModelSource, 'upstream');
    expect(c.restrictModels, isTrue);
    expect(c.groupIds, [1, 2]);
    expect(c.modelPricing.length, 1);
    expect(c.modelPricing.first.models, ['claude-3-5-sonnet']);
    expect(c.modelPricing.first.intervals.length, 1);
    // raw preserves complex fields for round-trip
    expect(c.raw['model_mapping'], isNotNull);
    expect(c.raw['account_stats_pricing_rules'], isNotNull);
  });

  test('ChannelModelPricing.toJson round-trips intervals', () {
    const p = ChannelModelPricing(
      platform: 'openai',
      models: ['gpt-4o'],
      billingMode: 'token',
      inputPrice: 0.0000025,
      intervals: [
        {'min_tokens': 0, 'max_tokens': null, 'tier_label': 'base'}
      ],
    );
    final j = p.toJson();
    expect(j['platform'], 'openai');
    expect(j['models'], ['gpt-4o']);
    expect((j['intervals'] as List).length, 1);
  });

  test('ChannelPage.fromJson', () {
    final pg = ChannelPage.fromJson({
      'items': [
        {'id': 1, 'name': 'a'},
        {'id': 2, 'name': 'b'},
      ],
      'total': 2,
    });
    expect(pg.items.length, 2);
    expect(pg.items.first.status, 'active');
  });
}
