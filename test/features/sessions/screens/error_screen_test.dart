import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_app/core/api/lib/totem_mobile_api.dart';
import 'package:totem_app/features/sessions/screens/error_screen.dart';

void main() {
  Future<void> pumpErrorScreen(
    WidgetTester tester, {
    VoidCallback? onRetry,
    Object? error,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RoomErrorScreen(
          onRetry: onRetry,
          error: error,
        ),
      ),
    );
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
          find.text("You've been removed from this session"),
          findsOneWidget,
        );
        expect(
          find.text(
            "You can still join other sessions, but you won't be able to "
            'access this one.',
          ),
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

        expect(find.text('This session has ended'), findsOneWidget);
        expect(
          find.text(
            'This session has already ended. You can still join other sessions.',
          ),
          findsOneWidget,
        );
      });

      testWidgets('shows retry button', (tester) async {
        await pumpErrorScreen(tester, error: endedError, onRetry: () {});

        expect(find.text('Retry'), findsOneWidget);
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
