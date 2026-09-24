import 'package:checks/checks.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_app/features/spaces/screens/spaces_discovery_screen.dart';
import 'package:totem_app/features/spaces/widgets/session_card.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/auth/models/auth_state.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/config/app_config.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/core/repositories/space_repository.dart';
import 'package:totem_core/shared/assets.dart';
import 'package:totem_core/shared/widgets/empty_indicator.dart';
import 'package:totem_core/shared/widgets/error_screen.dart';

final class _FakeAuthController extends AuthController {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);

  @override
  Future<void> checkExistingAuth() async {}

  @override
  Future<void> deleteAccount() async {}

  @override
  bool get isAuthenticated => false;

  @override
  Future<void> logout() async {}

  @override
  Stream<AuthState> get authStateChanges => const Stream.empty();

  @override
  UserSchema? get user => null;
}

MobileSpaceDetailSchema _space(String slug, String title, String category) =>
    MobileSpaceDetailSchema(
      slug: slug,
      title: title,
      imageLink: null,
      shortDescription: 'Description',
      content: '',
      author: PublicUserSchema(
        profileAvatarType: ProfileAvatarTypeEnum.td,
        name: const Omittable('Keeper'),
        dateCreated: DateTime.utc(2026),
      ),
      category: category,
      subscribers: 1,
      recurring: null,
      price: 0,
      nextEvents: [
        NextSessionSchema(
          slug: '$slug-session',
          start: DateTime.utc(2099, 1, 1),
          link: '',
          title: title,
          seatsLeft: 3,
          duration: 60,
          meetingProvider: MeetingProviderEnum.livekit,
          calLink: '',
          attending: false,
          cancelled: false,
          open: true,
          joinable: false,
        ),
      ],
    );

void main() {
  setUpAll(() {
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
  });

  testWidgets('discovery filters sessions by the selected category', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      tester.binding.imageCache.clearLiveImages();
      tester.binding.imageCache.clear();
      await const AssetImage(
        TotemImageAssets.genericBackground,
        package: 'totem_core',
      ).evict();
      await tester.binding.setSurfaceSize(null);
    });
    final support = _space('support', 'Support session', 'Support');
    final creativity = _space('creativity', 'Creative session', 'Creativity');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_FakeAuthController.new),
          spacesSummaryProvider.overrideWith(
            (_) async => SummarySpacesSchema(
              upcoming: const [],
              forYou: const [],
              explore: [support, creativity],
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const SpacesDiscoveryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    check(tester.widgetList(find.byType(SessionCard))).length.equals(2);
    await tester.tap(find.text('Support'));
    await tester.pumpAndSettle();

    check(tester.widgetList(find.byType(SessionCard))).length.equals(1);
    check(
      tester.widgetList(find.text('Support session')),
    ).length.isGreaterThan(0);
    check(tester.widgetList(find.text('Creative session'))).length.equals(0);
  });

  testWidgets('discovery shows an error and retries successfully', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      tester.binding.imageCache.clearLiveImages();
      tester.binding.imageCache.clear();
      await const AssetImage(
        TotemImageAssets.genericBackground,
        package: 'totem_core',
      ).evict();
      await tester.binding.setSurfaceSize(null);
    });
    var loads = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_FakeAuthController.new),
          spacesSummaryProvider.overrideWith((_) async {
            loads++;
            if (loads == 1) throw StateError('temporary failure');
            return const SummarySpacesSchema(
              upcoming: [],
              forYou: [],
              explore: [],
            );
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const SpacesDiscoveryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    check(tester.widgetList(find.byType(ErrorScreen))).length.equals(1);
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    check(loads).equals(2);
    check(tester.widgetList(find.byType(EmptyIndicator))).length.equals(1);
  });
}
