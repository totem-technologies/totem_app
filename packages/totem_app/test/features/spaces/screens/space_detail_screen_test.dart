import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_app/features/spaces/screens/space_detail_screen.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/auth/models/auth_state.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/core/repositories/space_repository.dart';
import 'package:totem_core/shared/router.dart';

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

MobileSpaceDetailSchema _space(String slug, String title) {
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
    nextEvents: const [],
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

void main() {
  setUpAll(() {
    setupAppConfig();
    silenceLogger();
    TotemRouter.instance = FakeTotemRouter();
  });

  testWidgets('shows the conflict dialog when RSVP overlaps a session', (
    tester,
  ) async {
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
          eventProvider(newSession.slug).overrideWith((_) async => newSession),
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

    expect(find.text('You have another session at this time.'), findsOneWidget);
    expect(find.text('Existing Session'), findsOneWidget);
    expect(find.text('New Session'), findsAtLeastNWidgets(1));
    expect(find.text('Switch Sessions'), findsOneWidget);
  });
}
