import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/repositories/space_repository.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/screens/error_screen.dart';

void main() {
  Future<void> pumpErrorScreen(
    WidgetTester tester, {
    VoidCallback? onRetry,
    Object? error,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentSessionStateProvider.overrideWithValue(null),
          getRecommendedSessionsProvider().overrideWith(
            (ref) => <SessionDetailSchema>[],
          ),
          spacesSummaryProvider.overrideWith(
            (ref) => throw UnimplementedError(),
          ),
        ],
        child: MaterialApp(
          home: SessionErrorScreen(
            onRetry: onRetry,
            error: error,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
  }

  group('RoomErrorScreen', () {
    group('generic error (no RoomErrorResponse)', () {
      testWidgets('shows default title and subtitle', (tester) async {
        await pumpErrorScreen(tester, onRetry: () {});

        expect(find.text('Something went wrong'), findsOneWidget);
        expect(
          find.text(
            "We couldn't connect you to this session. "
            'Please check your internet connection or try again.',
          ),
          findsOneWidget,
        );
      });

      testWidgets('shows retry button when onRetry is provided', (
        tester,
      ) async {
        await pumpErrorScreen(tester, onRetry: () {});

        expect(find.text('Retry'), findsOneWidget);
        expect(find.byType(OutlinedButton), findsOneWidget);
      });

      testWidgets('hides retry button when onRetry is null', (tester) async {
        await pumpErrorScreen(tester);

        expect(find.text('Retry'), findsNothing);
        expect(find.byType(OutlinedButton), findsNothing);
      });

      testWidgets('retry button invokes onRetry callback', (tester) async {
        var retryCount = 0;
        await pumpErrorScreen(tester, onRetry: () => retryCount++);

        await tester.tap(find.text('Retry'));
        await tester.pump();

        expect(retryCount, 1);
      });
    });

    group('banned error', () {
      const bannedError = RoomErrorResponse(
        code: ErrorCode.banned,
        message: 'You have been banned',
      );

      testWidgets('shows banned title and subtitle', (tester) async {
        await pumpErrorScreen(tester, error: bannedError, onRetry: () {});

        expect(
          find.text("You've been removed from this session."),
          findsOneWidget,
        );
        expect(
          find.textContaining('Please take a moment to review our'),
          findsOneWidget,
        );
      });

      testWidgets('does NOT show retry button even with onRetry provided', (
        tester,
      ) async {
        await pumpErrorScreen(tester, error: bannedError, onRetry: () {});

        expect(find.text('Retry'), findsNothing);
        expect(find.byType(OutlinedButton), findsNothing);
      });
    });

    group('roomAlreadyEnded error', () {
      const endedError = RoomErrorResponse(
        code: ErrorCode.roomAlreadyEnded,
        message: 'Room has ended',
      );

      testWidgets('shows ended title and subtitle', (tester) async {
        await pumpErrorScreen(tester, error: endedError, onRetry: () {});

        expect(find.text('Session Ended'), findsOneWidget);
        expect(
          find.textContaining('Thank you for joining!'),
          findsOneWidget,
        );
      });

      testWidgets('shows Explore More button', (tester) async {
        await pumpErrorScreen(tester, error: endedError, onRetry: () {});

        // SessionDisconnectedScreen shows Explore More, not Retry.
        expect(find.text('Explore More'), findsOneWidget);
      });
    });

    group('notJoinable error', () {
      const notJoinableError = RoomErrorResponse(
        code: ErrorCode.notJoinable,
        message: 'Not joinable',
      );

      testWidgets('shows notJoinable title and subtitle', (tester) async {
        await pumpErrorScreen(
          tester,
          error: notJoinableError,
          onRetry: () {},
        );

        expect(
          find.text('This session cannot be joined'),
          findsOneWidget,
        );
        expect(
          find.text(
            'You cannot join the session at this time. '
            'Please try again later.',
          ),
          findsOneWidget,
        );
      });

      testWidgets('shows retry button', (tester) async {
        await pumpErrorScreen(
          tester,
          error: notJoinableError,
          onRetry: () {},
        );

        expect(find.text('Retry'), findsOneWidget);
      });
    });

    group('RoomErrorResponse wrapped in ApiError', () {
      const wrappedError = ApiError<JoinResponse, RoomErrorResponse>(
        statusCode: 403,
        error: RoomErrorResponse(
          code: ErrorCode.notJoinable,
          message: 'Session is not joinable at this time',
        ),
      );

      testWidgets('unwraps and shows the specific copy', (tester) async {
        await pumpErrorScreen(tester, error: wrappedError, onRetry: () {});

        expect(
          find.text('This session cannot be joined'),
          findsOneWidget,
        );
        expect(find.text('Something went wrong'), findsNothing);
      });
    });

    group('unknown RoomErrorResponse code', () {
      const unknownError = RoomErrorResponse(
        code: ErrorCode.notInRoom,
        message: 'Not in room',
      );

      testWidgets('falls through to default title and subtitle', (
        tester,
      ) async {
        await pumpErrorScreen(tester, error: unknownError, onRetry: () {});

        expect(find.text('Something went wrong'), findsOneWidget);
        expect(
          find.text(
            "We couldn't connect you to this session. "
            'Please check your internet connection or try again.',
          ),
          findsOneWidget,
        );
      });

      testWidgets('shows retry button', (tester) async {
        await pumpErrorScreen(tester, error: unknownError, onRetry: () {});

        expect(find.text('Retry'), findsOneWidget);
      });
    });
  });
}
