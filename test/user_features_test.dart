import 'package:flutter_test/flutter_test.dart';
import 'package:sub2api/src/core/session/auth_models.dart';
import 'package:sub2api/src/features/user/features/data/user_features.dart';

void main() {
  PublicSettingsLite settings({
    bool payment = false,
    bool affiliate = false,
    bool channels = false,
    bool monitor = false,
    List<CustomMenuItem> items = const [],
  }) =>
      PublicSettingsLite(
        registrationEnabled: false,
        emailVerifyEnabled: false,
        turnstileEnabled: false,
        passwordResetEnabled: false,
        promoCodeEnabled: false,
        invitationCodeEnabled: false,
        paymentEnabled: payment,
        affiliateEnabled: affiliate,
        availableChannelsEnabled: channels,
        channelMonitorEnabled: monitor,
        customMenuItems: items,
      );

  test('enabledUserFeatures 只返回已开启的功能,且保持声明顺序', () {
    expect(enabledUserFeatures(settings()), isEmpty);

    final on = enabledUserFeatures(settings(payment: true, channels: true));
    expect(on.map((f) => f.id).toList(), ['recharge', 'availableChannels']);
    expect(on.first.route, '/recharge');
  });

  test('visibleCustomPages 按角色过滤并按 sort_order 升序', () {
    final s = settings(items: const [
      CustomMenuItem(id: 'b', label: 'B', visibility: 'user', sortOrder: 2),
      CustomMenuItem(id: 'a', label: 'A', visibility: 'user', sortOrder: 1),
      CustomMenuItem(id: 'x', label: 'X', visibility: 'admin', sortOrder: 0),
    ]);

    final asUser = visibleCustomPages(s, isAdmin: false);
    expect(asUser.map((e) => e.id).toList(), ['a', 'b']);

    final asAdmin = visibleCustomPages(s, isAdmin: true);
    expect(asAdmin.map((e) => e.id).toList(), ['x', 'a', 'b']);
  });
}
