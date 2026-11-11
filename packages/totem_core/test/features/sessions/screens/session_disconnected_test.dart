import 'package:checks/checks.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:livekit_client/livekit_client.dart' hide ConnectionState;
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/auth/models/auth_state.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/core/repositories/space_repository.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/screens/session_disconnected.dart';
import 'package:totem_core/features/sessions/widgets/background.dart';
import 'package:totem_core/shared/router.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/confetti.dart';
import 'package:totem_core/shared/widgets/space_card.dart';

import '../../../auth/controllers/auth_controller_mock.dart';
import '../../../setup.dart';

class MockSharedPreferences extends Mock implements SharedPreferences {}

class MockInAppReview extends Mock implements InAppReview {}

SessionRoomState _createEndedState({
  RoomStatus status = RoomStatus.ended,
  EndReason? endReason,
  bool removed = false,
  RemoveReason? removeReason,
  DisconnectReason? disconnectReason,
}) {
  return SessionRoomState(
    connection: ConnectionState(
      phase: status == RoomStatus.ended
          ? SessionPhase.ended
          : SessionPhase.connected,
      state: status == RoomStatus.ended
          ? RoomConnectionState.disconnected
          : RoomConnectionState.connected,
      error: disconnectReason != null
          ? RoomDisconnectionError(disconnectReason)
          : null,
    ),
    participants: ParticipantsState(
      participants: const [],
      removed: removed,
      removeReason: removeReason,
    ),
    chat: const ChatState(),
    turn: SessionTurnState(
      roomState: RoomState(
        keeper: 'keeper-1',
        nextSpeaker: const Omittable(''),
        currentSpeaker: const Omittable(''),
        status: status,
        turnState: TurnState.idle,
        sessionSlug: 'test-session',
        statusDetail: status == RoomStatus.ended
            ? RoomStateStatusDetailEnded(
                EndedDetail(reason: endReason ?? EndReason.keeperEnded),
              )
            : const RoomStateStatusDetailActive(ActiveDetail()),
        talkingOrder: const [],
        version: 1,
        roundNumber: 1,
      ),
    ),
  );
}

SessionDetailSchema _sessionWithNextEvent({
  String keeperName = 'Keeper Ada',
  String spaceTitle = 'Evening Circle',
  String nextTitle = 'Week Two',
}) {
  final next = NextSessionSchema(
    slug: 'next-session',
    start: DateTime.utc(2026, 11, 4, 18),
    link: 'https://example.com/next',
    title: nextTitle,
    seatsLeft: 4,
    duration: 60,
    meetingProvider: MeetingProviderEnum.livekit,
    calLink: '',
    attending: false,
    cancelled: false,
    open: true,
    joinable: true,
  );

  return SessionDetailSchema(
    slug: 'ended-session',
    title: 'Ended session',
    space: MobileSpaceDetailSchema(
      slug: 'test-space',
      title: spaceTitle,
      imageLink: null,
      shortDescription: 'A test space.',
      content: '',
      author: PublicUserSchema(
        profileAvatarType: ProfileAvatarTypeEnum.td,
        dateCreated: DateTime.utc(2024),
        name: Omittable(keeperName),
        slug: const Omittable('keeper-ada'),
      ),
      category: null,
      subscribers: 0,
      recurring: null,
      price: 0,
      nextEvents: [next],
    ),
    content: '',
    seatsLeft: 4,
    duration: 60,
    start: DateTime.utc(2026, 10, 27, 18),
    attending: true,
    open: true,
    started: true,
    cancelled: false,
    joinable: true,
    ended: true,
    rsvpUrl: '',
    joinUrl: null,
    subscribeUrl: '',
    calLink: '',
    subscribed: false,
    userTimezone: null,
    meetingProvider: MeetingProviderEnum.livekit,
  );
}

/// Serves a 1x1 transparent PNG for every image so [SpaceCard]'s fallback
/// background resolves without touching the real asset bundle.
class _FakeImageAssetBundle extends CachingAssetBundle {
  static final _transparentPng = Uint8List.fromList(const [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ]);

  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin') {
      return const StandardMessageCodec().encodeMessage(<Object?, Object?>{})!;
    }
    return ByteData.sublistView(_transparentPng);
  }
}

Future<void> _pumpDisconnectedScreen(
  WidgetTester tester, {
  required Size size,
  required SessionDetailSchema? session,
  SessionDisconnectedReason reason = SessionDisconnectedReason.keeperEnded,
  double textScale = 1,
  List<SessionDetailSchema> recommended = const [],
  TextDirection textDirection = TextDirection.ltr,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(
          () => FakeAuthController(AuthState.unauthenticated()),
        ),
        currentSessionProvider.overrideWithValue(null),
        currentSessionStateProvider.overrideWithValue(null),
        getRecommendedSessionsProvider(
          limit: 1,
        ).overrideWith((_) async => recommended),
        spacesSummaryProvider.overrideWith((_) async {
          throw UnimplementedError();
        }),
      ],
      child: DefaultAssetBundle(
        bundle: _FakeImageAssetBundle(),
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Directionality(
            textDirection: textDirection,
            child: Scaffold(
              body: RoomBackground(
                status: RoomStatus.ended,
                child: SessionDisconnectedScreen(
                  session: session,
                  sessionDisconnectedReason: reason,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  // Flush spacesSummary refresh timer from initState.
  await tester.pump(const Duration(milliseconds: 2800));
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    tester.binding.imageCache
      ..clearLiveImages()
      ..clear();
  });
}

Finder _keeperText(String keeperName) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is RichText && widget.text.toPlainText().contains(keeperName),
    description: 'RichText containing $keeperName',
  );
}

/// Whether the keeper row sits inside the card (not clipped by the card) and
/// inside the screen (not cut off by the page viewport).
bool _isKeeperFullyVisible(WidgetTester tester, String keeperName) {
  final keeperRect = tester.getRect(_keeperText(keeperName));
  final cardRect = tester.getRect(find.byType(SpaceCard)).inflate(0.5);
  final viewRect =
      (Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio)
          .inflate(0.5);
  return cardRect.contains(keeperRect.topLeft) &&
      cardRect.contains(keeperRect.bottomRight) &&
      viewRect.contains(keeperRect.topLeft) &&
      viewRect.contains(keeperRect.bottomRight);
}

/// Whether [finder]'s widget lies entirely inside the screen.
bool _isFullyVisible(WidgetTester tester, Finder finder) {
  final rect = tester.getRect(finder);
  final viewRect =
      (Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio)
          .inflate(0.5);
  return viewRect.contains(rect.topLeft) && viewRect.contains(rect.bottomRight);
}

/// Whether any scroll view on screen has content hidden past its edges.
bool _hasScrollableContent(WidgetTester tester) {
  return tester
      .stateList<ScrollableState>(find.byType(Scrollable))
      .any((state) => state.position.maxScrollExtent > 0);
}

void main() {
  group('SessionDisconnectedScreen', () {
    group('Reason Resolution (Unit Tests)', () {
      test('returns movedToAnotherDevice when duplicateIdentity', () {
        final result = resolveDisconnectedReason(
          disconnectReason: DisconnectReason.duplicateIdentity,
          sessionState: _createEndedState(),
        );

        check(result).equals(SessionDisconnectedReason.movedToAnotherDevice);
      });

      test('duplicateIdentity takes priority over removed', () {
        final result = resolveDisconnectedReason(
          disconnectReason: DisconnectReason.duplicateIdentity,
          sessionState: _createEndedState(removed: true),
        );

        check(result).equals(SessionDisconnectedReason.movedToAnotherDevice);
      });

      test('returns removed when participant was removed', () {
        final result = resolveDisconnectedReason(
          sessionState: _createEndedState(removed: true),
        );

        check(result).equals(SessionDisconnectedReason.removed);
      });

      test('removed takes priority over endReason', () {
        final result = resolveDisconnectedReason(
          sessionState: _createEndedState(
            removed: true,
            endReason: EndReason.keeperAbsent,
          ),
        );

        check(result).equals(SessionDisconnectedReason.removed);
      });

      test('returns banned when removeReason is ban', () {
        final result = resolveDisconnectedReason(
          sessionState: _createEndedState(
            removed: true,
            removeReason: RemoveReason.ban,
          ),
        );

        check(result).equals(SessionDisconnectedReason.banned);
      });

      test('banned takes priority over endReason', () {
        final result = resolveDisconnectedReason(
          sessionState: _createEndedState(
            removed: true,
            removeReason: RemoveReason.ban,
            endReason: EndReason.keeperEnded,
          ),
        );

        check(result).equals(SessionDisconnectedReason.banned);
      });

      test('returns keeperAbsent when EndReason.keeperAbsent', () {
        final result = resolveDisconnectedReason(
          sessionState: _createEndedState(endReason: EndReason.keeperAbsent),
        );

        check(result).equals(SessionDisconnectedReason.keeperAbsent);
      });

      test('returns roomEmpty when EndReason.roomEmpty', () {
        final result = resolveDisconnectedReason(
          sessionState: _createEndedState(endReason: EndReason.roomEmpty),
        );

        check(result).equals(SessionDisconnectedReason.roomEmpty);
      });

      test('returns keeperEnded when EndReason.keeperEnded', () {
        final result = resolveDisconnectedReason(
          sessionState: _createEndedState(endReason: EndReason.keeperEnded),
        );

        check(result).equals(SessionDisconnectedReason.keeperEnded);
      });

      test('returns keeperEnded for unrecognized EndReason values', () {
        final result = resolveDisconnectedReason(
          sessionState: _createEndedState(
            endReason: EndReason.fromJson('some_unknown'),
          ),
        );

        check(result).equals(SessionDisconnectedReason.keeperEnded);
      });

      test('returns keeperEnded when sessionState is null', () {
        final result = resolveDisconnectedReason();

        check(result).equals(SessionDisconnectedReason.keeperEnded);
      });

      test('returns keeperEnded when room status is not ended', () {
        final result = resolveDisconnectedReason(
          sessionState: _createEndedState(status: RoomStatus.active),
        );

        check(result).equals(SessionDisconnectedReason.keeperEnded);
      });
    });

    group('App Review Logic (Unit Tests)', () {
      late MockSharedPreferences prefs;
      late MockInAppReview inAppReview;

      setUp(() {
        prefs = MockSharedPreferences();
        inAppReview = MockInAppReview();
      });

      test('does nothing if review already requested', () async {
        when(
          () => prefs.getBool(SessionDisconnectedScreen.reviewRequestedKey),
        ).thenReturn(true);

        await SessionDisconnectedScreen.incrementSessionLikedCount(
          prefs: prefs,
          inAppReview: inAppReview,
        );

        verifyNever(
          () => prefs.setInt(
            SessionDisconnectedScreen.sessionLikedCountKey,
            any(),
          ),
        );
        verifyNever(() => inAppReview.requestReview());
      });

      test(
        'increments count and does not request review if count < 5',
        () async {
          when(
            () => prefs.getBool(SessionDisconnectedScreen.reviewRequestedKey),
          ).thenReturn(false);
          when(
            () => prefs.getInt(SessionDisconnectedScreen.sessionLikedCountKey),
          ).thenReturn(2);
          when(
            () =>
                prefs.setInt(SessionDisconnectedScreen.sessionLikedCountKey, 3),
          ).thenAnswer((_) async => true);

          await SessionDisconnectedScreen.incrementSessionLikedCount(
            prefs: prefs,
            inAppReview: inAppReview,
          );

          verify(
            () =>
                prefs.setInt(SessionDisconnectedScreen.sessionLikedCountKey, 3),
          ).called(1);
          verifyNever(() => inAppReview.requestReview());
        },
      );

      test('requests review and sets key when count reaches 5', () async {
        when(
          () => prefs.getBool(SessionDisconnectedScreen.reviewRequestedKey),
        ).thenReturn(false);
        when(
          () => prefs.getInt(SessionDisconnectedScreen.sessionLikedCountKey),
        ).thenReturn(4);
        when(
          () => prefs.setInt(SessionDisconnectedScreen.sessionLikedCountKey, 5),
        ).thenAnswer((_) async => true);
        when(
          () =>
              prefs.setBool(SessionDisconnectedScreen.reviewRequestedKey, true),
        ).thenAnswer((_) async => true);

        when(() => inAppReview.isAvailable()).thenAnswer((_) async => true);
        when(
          () => inAppReview.requestReview(),
        ).thenAnswer((_) async => Future.value());

        await SessionDisconnectedScreen.incrementSessionLikedCount(
          prefs: prefs,
          inAppReview: inAppReview,
        );

        verify(
          () => prefs.setInt(SessionDisconnectedScreen.sessionLikedCountKey, 5),
        ).called(1);
        verify(() => inAppReview.isAvailable()).called(1);
        verify(() => inAppReview.requestReview()).called(1);
        verify(
          () =>
              prefs.setBool(SessionDisconnectedScreen.reviewRequestedKey, true),
        ).called(1);
      });

      test('does not request review if not available', () async {
        when(
          () => prefs.getBool(SessionDisconnectedScreen.reviewRequestedKey),
        ).thenReturn(false);
        when(
          () => prefs.getInt(SessionDisconnectedScreen.sessionLikedCountKey),
        ).thenReturn(4);
        when(
          () => prefs.setInt(SessionDisconnectedScreen.sessionLikedCountKey, 5),
        ).thenAnswer((_) async => true);

        when(() => inAppReview.isAvailable()).thenAnswer((_) async => false);

        await SessionDisconnectedScreen.incrementSessionLikedCount(
          prefs: prefs,
          inAppReview: inAppReview,
        );

        verify(
          () => prefs.setInt(SessionDisconnectedScreen.sessionLikedCountKey, 5),
        ).called(1);
        verify(() => inAppReview.isAvailable()).called(1);
        verifyNever(() => inAppReview.requestReview());
        verifyNever(
          () =>
              prefs.setBool(SessionDisconnectedScreen.reviewRequestedKey, true),
        );
      });

      test('handles errors silently', () async {
        when(
          () => prefs.getBool(SessionDisconnectedScreen.reviewRequestedKey),
        ).thenReturn(false);
        when(
          () => prefs.getInt(SessionDisconnectedScreen.sessionLikedCountKey),
        ).thenReturn(4);
        when(
          () => prefs.setInt(SessionDisconnectedScreen.sessionLikedCountKey, 5),
        ).thenAnswer((_) async => true);

        when(() => inAppReview.isAvailable()).thenAnswer((_) async => true);
        when(
          () => inAppReview.requestReview(),
        ).thenThrow(Exception('Simulated error'));

        // Should not throw
        await SessionDisconnectedScreen.incrementSessionLikedCount(
          prefs: prefs,
          inAppReview: inAppReview,
        );

        verify(() => inAppReview.requestReview()).called(1);
        // setBool should NOT be called if it threw before
        verifyNever(
          () =>
              prefs.setBool(SessionDisconnectedScreen.reviewRequestedKey, true),
        );
      });
    });

    group('Next Session card layout (TOT-1439)', () {
      const keeper = 'Keeper Ada';
      final seeAllSessions = find.text('See all upcoming sessions');

      setUp(() => TotemRouter.instance = FakeTotemRouter());

      // Phone portrait, the reported desktop (TOT-1439), a laptop, a tall
      // desktop, and the short desktop, short tablet and landscape windows
      // from review.
      for (final size in const [
        Size(390, 844),
        Size(1440, 900),
        Size(1280, 800),
        Size(1600, 1100),
        Size(1702, 650),
        Size(812, 650),
        Size(700, 650),
        Size(906, 339),
      ]) {
        testWidgets('shows the whole card and actions without scrolling at '
            '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
          await _pumpDisconnectedScreen(
            tester,
            size: size,
            session: _sessionWithNextEvent(keeperName: keeper),
          );

          check(_isKeeperFullyVisible(tester, keeper)).isTrue();
          check(_isFullyVisible(tester, find.byType(SpaceCard))).isTrue();
          check(_isFullyVisible(tester, seeAllSessions)).isTrue();
          check(_hasScrollableContent(tester)).isFalse();
        });
      }

      for (final size in const [
        Size(1702, 650),
        Size(812, 650),
        Size(700, 650),
        Size(906, 339),
        Size(1280, 800),
      ]) {
        testWidgets('places the card beside the header at '
            '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
          await _pumpDisconnectedScreen(
            tester,
            size: size,
            session: _sessionWithNextEvent(keeperName: keeper),
          );

          final headerRect = tester.getRect(find.text('Session Ended'));
          final cardRect = tester.getRect(find.byType(SpaceCard));
          check(cardRect.left).isGreaterOrEqual(headerRect.right);
        });
      }

      for (final size in const [Size(1440, 900), Size(1600, 1100)]) {
        testWidgets('stacks the card below the header at '
            '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
          await _pumpDisconnectedScreen(
            tester,
            size: size,
            session: _sessionWithNextEvent(keeperName: keeper),
          );

          final headerRect = tester.getRect(find.text('Session Ended'));
          final cardRect = tester.getRect(find.byType(SpaceCard));
          check(cardRect.top).isGreaterOrEqual(headerRect.bottom);
        });
      }

      testWidgets(
        'short desktop with large text scrolls to reveal the whole card',
        (tester) async {
          await _pumpDisconnectedScreen(
            tester,
            size: const Size(1702, 650),
            textScale: 2,
            session: _sessionWithNextEvent(keeperName: keeper),
          );

          await tester.ensureVisible(_keeperText(keeper));
          await tester.pump();

          check(_isKeeperFullyVisible(tester, keeper)).isTrue();
        },
      );

      testWidgets(
        'narrow short window with large text does not clip the card',
        (tester) async {
          await _pumpDisconnectedScreen(
            tester,
            size: const Size(720, 650),
            textScale: 2,
            session: _sessionWithNextEvent(keeperName: keeper),
          );

          await tester.ensureVisible(_keeperText(keeper));
          await tester.pump();

          check(_isKeeperFullyVisible(tester, keeper)).isTrue();
        },
      );

      // Reasons with longer copy and no feedback bar, at heights where the
      // keeperEnded copy would still stack.
      for (final reason in const [
        SessionDisconnectedReason.removed,
        SessionDisconnectedReason.keeperAbsent,
        SessionDisconnectedReason.movedToAnotherDevice,
      ]) {
        for (final size in const [
          Size(620, 770),
          Size(812, 770),
          Size(1000, 770),
        ]) {
          testWidgets(
            'shows the whole card for ${reason.name} without scrolling at '
            '${size.width.toInt()}x${size.height.toInt()}',
            (tester) async {
              await _pumpDisconnectedScreen(
                tester,
                size: size,
                reason: reason,
                session: _sessionWithNextEvent(keeperName: keeper),
              );

              check(_isKeeperFullyVisible(tester, keeper)).isTrue();
              check(_isFullyVisible(tester, seeAllSessions)).isTrue();
              check(_hasScrollableContent(tester)).isFalse();
            },
          );
        }
      }

      testWidgets(
        'removed participant sees a recommended session beside the header',
        (tester) async {
          final recommended = _sessionWithNextEvent(
            keeperName: 'Keeper Bo',
          ).copyWith(slug: 'recommended-session');
          await _pumpDisconnectedScreen(
            tester,
            size: const Size(1702, 650),
            session: null,
            reason: SessionDisconnectedReason.removed,
            recommended: [recommended],
          );
          await tester.pump();

          check(find.text('You may enjoy this space').evaluate()).isNotEmpty();
          check(_isKeeperFullyVisible(tester, 'Keeper Bo')).isTrue();
          check(_isFullyVisible(tester, seeAllSessions)).isTrue();
          check(_hasScrollableContent(tester)).isFalse();
        },
      );

      testWidgets(
        'short desktop without a next session fits without scrolling',
        (tester) async {
          await _pumpDisconnectedScreen(
            tester,
            size: const Size(1702, 650),
            session: null,
          );

          check(find.byType(SpaceCard).evaluate()).isEmpty();
          check(_isFullyVisible(tester, seeAllSessions)).isTrue();
          check(_hasScrollableContent(tester)).isFalse();
        },
      );

      testWidgets('right-to-left places the card before the header', (
        tester,
      ) async {
        await _pumpDisconnectedScreen(
          tester,
          size: const Size(1702, 650),
          session: _sessionWithNextEvent(keeperName: keeper),
          textDirection: TextDirection.rtl,
        );

        final headerRect = tester.getRect(find.text('Session Ended'));
        final cardRect = tester.getRect(find.byType(SpaceCard));
        check(cardRect.right).isLessOrEqual(headerRect.left);
        check(_isKeeperFullyVisible(tester, keeper)).isTrue();
        check(_hasScrollableContent(tester)).isFalse();
      });

      testWidgets('short portrait scrolls the page to reveal the full card', (
        tester,
      ) async {
        await _pumpDisconnectedScreen(
          tester,
          size: const Size(390, 560),
          session: _sessionWithNextEvent(keeperName: keeper),
        );

        await tester.ensureVisible(_keeperText(keeper));
        await tester.pump();

        check(_isKeeperFullyVisible(tester, keeper)).isTrue();
      });

      testWidgets(
        'narrow phone with large text and a long title does not clip keeper',
        (tester) async {
          await _pumpDisconnectedScreen(
            tester,
            size: const Size(320, 640),
            textScale: 1.5,
            session: _sessionWithNextEvent(
              keeperName: keeper,
              spaceTitle: 'A Much Longer Evening Circle Name',
              nextTitle: 'Week Two: Listening Deeply Together',
            ),
          );

          await tester.ensureVisible(_keeperText(keeper));
          await tester.pump();

          check(_isKeeperFullyVisible(tester, keeper)).isTrue();
        },
      );

      testWidgets(
        'very short landscape with large text scrolls to reveal the whole card',
        (tester) async {
          await _pumpDisconnectedScreen(
            tester,
            size: const Size(740, 340),
            textScale: 1.5,
            session: _sessionWithNextEvent(keeperName: keeper),
          );

          await tester.ensureVisible(_keeperText(keeper));
          await tester.pump();

          check(_isKeeperFullyVisible(tester, keeper)).isTrue();
        },
      );

      testWidgets(
        'keeps the feedback selection when a resize switches layouts',
        (tester) async {
          var likes = 0;
          final thumbUp = find.byWidgetPredicate(
            (widget) =>
                widget is TotemIcon && widget.icon == TotemIcons.thumbUp,
          );
          tester.view
            ..physicalSize = const Size(1280, 1000)
            ..devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                authControllerProvider.overrideWith(
                  () => FakeAuthController(AuthState.unauthenticated()),
                ),
              ],
              child: DefaultAssetBundle(
                bundle: _FakeImageAssetBundle(),
                child: MaterialApp(
                  home: Scaffold(
                    body: SessionDisconnectedView(
                      reason: SessionDisconnectedReason.keeperEnded,
                      nextSession: NextSessionPromo(
                        space: _sessionWithNextEvent().space,
                        onTap: () {},
                      ),
                      onLike: () async => likes++,
                      onDislike: (_) async {},
                      onGoHome: () {},
                    ),
                  ),
                ),
              ),
            ),
          );

          final headerRect = tester.getRect(find.text('Session Ended'));
          check(
            tester.getRect(find.byType(SpaceCard)).top,
          ).isGreaterOrEqual(headerRect.bottom);

          await tester.tap(thumbUp);
          await tester.pump();
          check(likes).equals(1);
          check(
            find.text('Thank you! Glad you enjoyed it.').evaluate(),
          ).isNotEmpty();

          tester.view.physicalSize = const Size(1280, 700);
          await tester.pump();

          check(
            tester.getRect(find.byType(SpaceCard)).left,
          ).isGreaterOrEqual(tester.getRect(find.text('Session Ended')).right);
          check(
            find.text('Thank you! Glad you enjoyed it.').evaluate(),
          ).isNotEmpty();

          await tester.tap(thumbUp, warnIfMissed: false);
          await tester.pump();
          check(likes).equals(1);

          ConfettiController.clear();
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          tester.binding.imageCache
            ..clearLiveImages()
            ..clear();
        },
        // AutoSizeText doesn't dispose the painters it measures with.
        experimentalLeakTesting: LeakTesting.settings.withIgnored(
          classes: <String>['TextPainter'],
        ),
      );

      testWidgets('tablet renders keeperEnded without session details', (
        tester,
      ) async {
        await _pumpDisconnectedScreen(
          tester,
          size: const Size(800, 1100),
          session: null,
        );

        check(find.text('Session Ended').evaluate()).isNotEmpty();
        check(seeAllSessions.evaluate()).isNotEmpty();
      });
    });
  });
}
