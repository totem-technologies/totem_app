import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:checks/checks.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_app/features/spaces/screens/space_detail_screen.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/auth/models/auth_state.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/core/repositories/space_repository.dart';
import 'package:totem_core/shared/assets.dart';
import 'package:totem_core/shared/router.dart';
import 'package:totem_core/shared/widgets/confetti.dart';

import '../../../../../totem_core/test/setup.dart';

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

MobileSpaceDetailSchema _space(
  String slug,
  String title, {
  List<NextSessionSchema> nextEvents = const [],
}) {
  return MobileSpaceDetailSchema(
    slug: slug,
    title: title,
    imageLink: null,
    shortDescription: 'A test space',
    content: '',
    author: PublicUserSchema(
      profileAvatarType: ProfileAvatarTypeEnum.td,
      name: 'Test Keeper',
      dateCreated: DateTime.utc(2026),
    ),
    category: null,
    subscribers: 1,
    recurring: null,
    price: 0,
    nextEvents: nextEvents,
  );
}

SessionDetailSchema _session({
  required String slug,
  required String title,
  required MobileSpaceDetailSchema space,
  required bool attending,
}) {
  return SessionDetailSchema(
    slug: slug,
    title: title,
    space: space,
    content: '',
    seatsLeft: 5,
    duration: 60,
    start: DateTime.now().add(const Duration(days: 7)),
    attending: attending,
    open: true,
    started: false,
    cancelled: false,
    joinable: false,
    ended: false,
    rsvpUrl: '/rsvp/$slug',
    joinUrl: null,
    subscribeUrl: '/subscribe/$slug',
    calLink: '/calendar/$slug',
    subscribed: true,
    userTimezone: 'UTC',
    meetingProvider: MeetingProviderEnum.livekit,
  );
}

const _emptySummary = SummarySpacesSchema(
  upcoming: [],
  forYou: [],
  explore: [],
);

void main() {
  setUpAll(() {
    setupAppConfig();
    silenceLogger();
    TotemRouter.instance = FakeTotemRouter();
  });

  testWidgets('shows the conflict dialog when RSVP overlaps a session', (
    tester,
  ) async {
    addTearDown(() async {
      ConfettiController.clear();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      tester.binding.imageCache.clearLiveImages();
      tester.binding.imageCache.clear();
    });

    final newSpace = _space('new-space', 'New Space');
    final existingSpace = _space('existing-space', 'Existing Space');
    final newSession = _session(
      slug: 'new-session',
      title: 'New Session',
      space: newSpace,
      attending: false,
    );
    final existingSession = _session(
      slug: 'existing-session',
      title: 'Existing Session',
      space: existingSpace,
      attending: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_FakeAuthController.new),
          spaceProvider(newSpace.slug).overrideWith((_) async => newSpace),
          sessionProvider(
            newSession.slug,
          ).overrideWith((_) async => newSession),
          rsvpConfirmProvider(newSession.slug).overrideWith(
            (_) async => throw RsvpConflictException(
              SessionConflictSchema(
                message: 'Conflict',
                conflictingSessions: [existingSession],
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: SpaceDetailScreen(
            slug: newSpace.slug,
            sessionSlug: newSession.slug,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Attend'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    check(
      tester.widgetList(find.text('You have a session at this time.')),
    ).length.equals(1);
    check(tester.widgetList(find.text('Existing Session'))).length.equals(1);
    check(
      tester.widgetList(find.text('New Session')),
    ).length.isGreaterOrEqual(1);
    check(tester.widgetList(find.text('Switch Sessions'))).length.equals(1);
  });

  testWidgets('invalidates the spaces summary after a successful RSVP', (
    tester,
  ) async {
    addTearDown(() async {
      ConfettiController.clear();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      tester.binding.imageCache.clearLiveImages();
      tester.binding.imageCache.clear();
    });

    var summaryLoads = 0;
    final space = _space('new-space', 'New Space');
    final session = _session(
      slug: 'new-session',
      title: 'New Session',
      space: space,
      attending: false,
    );
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_FakeAuthController.new),
        spaceProvider(space.slug).overrideWith((_) async => space),
        sessionProvider(session.slug).overrideWith((_) async => session),
        rsvpConfirmProvider(session.slug).overrideWith((_) async => true),
        spacesSummaryProvider.overrideWith((_) async {
          summaryLoads++;
          return _emptySummary;
        }),
      ],
    );
    addTearDown(container.dispose);

    await container.read(spacesSummaryProvider.future);
    check(summaryLoads).equals(1);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: SpaceDetailScreen(slug: space.slug, sessionSlug: session.slug),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Attend'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    check(tester.widgetList(find.text("You're going!"))).length.equals(1);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await container.read(spacesSummaryProvider.future);

    check(summaryLoads).equals(2);
    ConfettiController.clear();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    tester.binding.imageCache.clearLiveImages();
    tester.binding.imageCache.clear();
  });

  testWidgets('refreshes the current state after returning from a session', (
    tester,
  ) async {
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await const AssetImage(
        TotemImageAssets.genericBackground,
        package: 'totem_core',
      ).evict();
      tester.binding.imageCache.clearLiveImages();
      tester.binding.imageCache.clear();
    });

    var spaceLoads = 0;
    var eventLoads = 0;
    var summaryLoads = 0;
    final upcomingSession = NextSessionSchema(
      slug: 'upcoming-session',
      start: DateTime.now().add(const Duration(days: 14)),
      link: '/sessions/upcoming-session',
      title: 'Upcoming Session',
      seatsLeft: 4,
      duration: 60,
      meetingProvider: MeetingProviderEnum.livekit,
      calLink: '/calendar/upcoming-session',
      attending: false,
      cancelled: false,
      open: true,
      joinable: false,
    );
    final space = _space(
      'new-space',
      'New Space',
      nextEvents: [upcomingSession],
    );
    final currentSession = _session(
      slug: 'current-session',
      title: 'Current Session',
      space: space,
      attending: true,
    );
    final refreshedCurrentSession = _session(
      slug: 'current-session',
      title: 'Current Session',
      space: space,
      attending: false,
    );
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_FakeAuthController.new),
        spaceProvider(space.slug).overrideWith((_) async {
          spaceLoads++;
          return space;
        }),
        sessionProvider(currentSession.slug).overrideWith((_) async {
          eventLoads++;
          return eventLoads == 1 ? currentSession : refreshedCurrentSession;
        }),
        spacesSummaryProvider.overrideWith((_) async {
          summaryLoads++;
          return _emptySummary;
        }),
      ],
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => SpaceDetailScreen(
            slug: space.slug,
            sessionSlug: currentSession.slug,
          ),
        ),
        GoRoute(
          path: '/spaces/:spaceSlug/session/:eventSlug',
          builder: (_, _) => const Scaffold(body: Text('Other session')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await container.read(spacesSummaryProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    check((spaceLoads, eventLoads, summaryLoads)).equals((1, 1, 1));
    check(
      tester.widgetList(find.byTooltip('Give up your spot')),
    ).length.equals(1);

    await tester.scrollUntilVisible(
      find.text('Upcoming Session'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Upcoming Session'));
    await tester.pumpAndSettle();
    check(tester.widgetList(find.text('Other session'))).length.equals(1);

    router.pop();
    await tester.pumpAndSettle();
    await container.read(spacesSummaryProvider.future);

    check((spaceLoads, eventLoads, summaryLoads)).equals((2, 2, 2));
    check(tester.widgetList(find.text('Attend'))).length.equals(1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await const AssetImage(
      TotemImageAssets.genericBackground,
      package: 'totem_core',
    ).evict();
    tester.binding.imageCache.clearLiveImages();
    tester.binding.imageCache.clear();
  });
}
