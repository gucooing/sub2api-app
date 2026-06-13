import 'package:flutter_test/flutter_test.dart';
import 'package:sub2api/src/features/user/affiliate/data/affiliate_api.dart';
import 'package:sub2api/src/features/user/channels_view/data/channels_api.dart';
import 'package:sub2api/src/features/user/recharge/data/recharge_api.dart';

void main() {
  group('充值 recharge', () {
    test('CheckoutInfo 解析:过滤不可用方式、套餐按 sort_order 且只留 for_sale', () {
      final info = CheckoutInfo.fromJson({
        'methods': {
          'alipay': {
            'available': true,
            'single_min': 1,
            'single_max': 1000,
            'fee_rate': 0.02,
          },
          'wxpay': {'available': false},
        },
        'global_min': 5,
        'global_max': 500,
        'balance_recharge_multiplier': 1.1,
        'plans': [
          {'id': 2, 'name': 'B', 'price': 20, 'sort_order': 2, 'for_sale': true},
          {'id': 1, 'name': 'A', 'price': 10, 'sort_order': 1, 'for_sale': true},
          {'id': 3, 'name': 'C', 'price': 30, 'sort_order': 0, 'for_sale': false},
        ],
      });
      expect(info.methods, hasLength(1));
      expect(info.methods.first.key, 'alipay');
      expect(info.methods.first.feeRate, 0.02);
      expect(info.globalMin, 5);
      expect(info.balanceRechargeMultiplier, 1.1);
      // 只剩 for_sale,且按 sort_order 升序。
      expect(info.plans.map((p) => p.id).toList(), [1, 2]);
    });

    test('CreateOrderResult / PaymentOrder 解析', () {
      final r = CreateOrderResult.fromJson({
        'order_id': 9,
        'amount': 50,
        'pay_amount': 51,
        'result_type': 'order_created',
        'qr_code': 'data:abc',
        'out_trade_no': 'T123',
      });
      expect(r.orderId, 9);
      expect(r.payAmount, 51);
      expect(r.qrCode, 'data:abc');
      expect(r.outTradeNo, 'T123');

      final o = PaymentOrder.fromJson({
        'id': 1,
        'amount': 50,
        'pay_amount': 51,
        'payment_type': 'alipay',
        'out_trade_no': 'T123',
        'status': 'PENDING',
        'order_type': 'balance',
        'created_at': '2026-06-14T10:00:00Z',
      });
      expect(o.status, 'PENDING');
      expect(o.paymentType, 'alipay');
      expect(o.createdAt, isNotNull);
    });
  });

  group('邀请返利 affiliate', () {
    test('AffiliateDetail 解析含被邀请人', () {
      final d = AffiliateDetail.fromJson({
        'aff_code': 'INV123',
        'aff_count': 2,
        'aff_quota': 12.5,
        'aff_frozen_quota': 3.0,
        'aff_history_quota': 40.0,
        'effective_rebate_rate_percent': 15,
        'invitees': [
          {
            'user_id': 7,
            'email': 'a@x.com',
            'username': 'a',
            'total_rebate': 5.5,
            'created_at': '2026-05-01T00:00:00Z',
          },
        ],
      });
      expect(d.affCode, 'INV123');
      expect(d.affCount, 2);
      expect(d.affQuota, 12.5);
      expect(d.rebateRatePercent, 15);
      expect(d.invitees, hasLength(1));
      expect(d.invitees.first.totalRebate, 5.5);
      expect(d.invitees.first.createdAt, isNotNull);
    });
  });

  group('渠道 channels', () {
    test('AvailableChannel 解析平台/分组/模型定价', () {
      final list = [
        {
          'name': 'Ch1',
          'description': 'desc',
          'platforms': [
            {
              'platform': 'anthropic',
              'groups': [
                {
                  'id': 1,
                  'name': 'VIP',
                  'platform': 'anthropic',
                  'subscription_type': 'subscription',
                  'rate_multiplier': 0.8,
                  'is_exclusive': true,
                },
              ],
              'supported_models': [
                {
                  'name': 'claude-x',
                  'platform': 'anthropic',
                  'pricing': {'input_price': 3.0, 'output_price': 15.0},
                },
              ],
            },
          ],
        },
      ];
      final channels = list
          .map((e) => AvailableChannel.fromJson(e))
          .toList();
      expect(channels, hasLength(1));
      final p = channels.first.platforms.first;
      expect(p.platform, 'anthropic');
      expect(p.groups.first.isSubscription, isTrue);
      expect(p.groups.first.rateMultiplier, 0.8);
      expect(p.supportedModels.first.inputPrice, 3.0);
      expect(p.supportedModels.first.outputPrice, 15.0);
    });

    test('MonitorView 状态/时间轴解析;状态映射', () {
      final m = MonitorView.fromJson({
        'id': 5,
        'name': 'M5',
        'provider': 'anthropic',
        'group_name': 'G',
        'primary_model': 'claude-x',
        'primary_status': 'operational',
        'availability_7d': 99.5,
        'primary_latency_ms': 320,
        'timeline': [
          {'status': 'operational', 'checked_at': '2026-06-14T10:00:00Z'},
          {'status': 'failed', 'checked_at': '2026-06-14T11:00:00Z'},
        ],
      });
      expect(m.primaryStatus, MonitorStatus.operational);
      expect(m.availability7d, 99.5);
      expect(m.timeline, hasLength(2));
      expect(m.timeline[1].status, MonitorStatus.failed);
      // error 归并到 failed,未知字符串归 unknown。
      expect(parseMonitorStatus('error'), MonitorStatus.failed);
      expect(parseMonitorStatus(null), MonitorStatus.unknown);
    });

    test('MonitorDetail 多窗口可用率解析', () {
      final d = MonitorDetail.fromJson({
        'id': 5,
        'name': 'M5',
        'provider': 'anthropic',
        'group_name': 'G',
        'models': [
          {
            'model': 'claude-x',
            'latest_status': 'degraded',
            'availability_7d': 98.0,
            'availability_15d': 97.0,
            'availability_30d': 96.0,
            'avg_latency_7d_ms': 410,
          },
        ],
      });
      expect(d.models, hasLength(1));
      expect(d.models.first.latestStatus, MonitorStatus.degraded);
      expect(d.models.first.availability30d, 96.0);
      expect(d.models.first.avgLatency7dMs, 410);
    });
  });
}
