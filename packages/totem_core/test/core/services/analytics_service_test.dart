import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/services/analytics_service.dart';

import '../../setup.dart';

void main() {
  setUp(() async {
    setupAppConfig();
    await Sentry.init((options) {
      options.dsn = 'https://public@sentry.example.com/1';
    });
  });

  tearDown(Sentry.close);

  test('identifies the user to Sentry even when analytics is off', () async {
    final user = UserSchema(
      slug: const Omittable('xvt124jmb'),
      name: const Omittable('Jay'),
      profileAvatarType: ProfileAvatarTypeEnum.td,
      circleCount: 0,
      email: 'jay@example.com',
      dateCreated: DateTime(2024),
    );

    await AnalyticsService.instance.setUserId(user);

    SentryUser? sentryUser;
    await Sentry.configureScope((scope) => sentryUser = scope.user);
    check(sentryUser).isNotNull()
      ..has((u) => u.id, 'id').equals('xvt124jmb')
      ..has((u) => u.name, 'name').equals('Jay');
  });
}
