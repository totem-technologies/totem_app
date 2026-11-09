import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_app/features/auth/controllers/auth_controller.dart';
import 'package:totem_app/features/auth/controllers/user_profile_controller.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/auth/models/auth_state.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/config/app_config.dart';
import 'package:totem_core/shared/widgets/loading_indicator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_app/features/profile/screens/profile_image_picker.dart';

final class _FakeAuthController extends MobileAuthController {
  _FakeAuthController(this.user);

  @override
  final UserSchema user;

  @override
  AuthState build() => AuthState.authenticated(user: user);
}

final class _FakeUserProfileController extends UserProfileController {
  final firstUpdate = Completer<bool>();
  var calls = 0;

  @override
  FutureOr<void> build() {}

  @override
  Future<bool> updateUserProfile({
    String? name,
    String? email,
    Object? profileImage,
    Object? profileAvatarType,
    String? avatarSeed,
  }) {
    calls++;
    return calls == 1 ? firstUpdate.future : Future.value(true);
  }
}

List<int> header(String type, String brand) => [
  0,
  0,
  0,
  24,
  ...type.codeUnits,
  ...brand.codeUnits,
];

void main() {
  testWidgets('avatar save recovers from an exception and can be retried', (
    tester,
  ) async {
    AppConfig.instance = AppConfig(
      environment: Environment.development,
      apiUrl: 'https://test.example.com/',
      liveKitUrl: 'wss://test.livekit.cloud',
      maxPinAttempts: 5,
      vapidKey: null,
      analyticsEnabled: false,
      sentryDsn: null,
      posthogApiKey: null,
      posthogHost: 'https://us.i.posthog.com',
      privacyPolicyUrl: Uri.parse('https://example.com/privacy'),
      termsOfServiceUrl: Uri.parse('https://example.com/tos'),
      communityGuidelinesUrl: Uri.parse('https://example.com/guidelines'),
    );
    final user = UserSchema(
      name: Omittable('User'),
      profileAvatarType: ProfileAvatarTypeEnum.td,
      circleCount: 0,
      email: 'user@example.com',
      dateCreated: DateTime.utc(2024),
    );
    final auth = _FakeAuthController(user);
    final profile = _FakeUserProfileController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(() => auth),
          userProfileControllerProvider.overrideWith(() => profile),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showProfileImagePicker(context),
                child: const Text('Open picker'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pump();
    check(profile.calls).equals(1);
    check(tester.widgetList(find.byType(LoadingIndicator))).length.equals(1);

    profile.firstUpdate.completeError(Exception('save failed'));
    await tester.pump();
    check(tester.takeException()).isNull();
    check(tester.widgetList(find.byType(LoadingIndicator))).isEmpty();
    check(tester.widgetList(find.text('Save'))).length.equals(1);

    await tester.tap(find.text('Save'));
    await tester.pump();
    check(profile.calls).equals(2);
    await tester.pumpAndSettle();
    check(tester.widgetList(find.text('Open picker'))).length.equals(1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  for (final brand in [
    'heic',
    'heix',
    'hevc',
    'heim',
    'heis',
    'mif1',
    'msf1',
  ]) {
    test('recognizes the $brand HEIF brand', () {
      check(isHeifImageHeader(header('ftyp', brand))).equals(true);
    });
  }

  test('rejects incomplete headers', () {
    final complete = header('ftyp', 'heic');
    for (var length = 0; length < 12; length++) {
      check(isHeifImageHeader(complete.sublist(0, length))).equals(false);
    }
  });

  test('rejects other file types and brands', () {
    check(isHeifImageHeader(header('free', 'heic'))).equals(false);
    check(isHeifImageHeader(header('ftyp', 'mp42'))).equals(false);
    check(
      isHeifImageHeader([0xff, 0xd8, 0xff, 0xe0, 0, 0, 0, 0, 0, 0, 0, 0]),
    ).equals(false);
  });
}
