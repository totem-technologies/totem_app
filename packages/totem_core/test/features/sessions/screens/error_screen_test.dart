import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/repositories/space_repository.dart';
import 'package:totem_core/core/services/connectivity_service.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/screens/error_screen.dart';
import 'package:totem_core/features/sessions/screens/session_disconnected.dart';
import 'package:totem_core/shared/totem_icons.dart';

void main() {
  Future<void> pumpErrorScreen(
    WidgetTester tester, {
    AsyncCallback? onRetry,
    Object? error,
    bool initiallyOffline = false,
    Stream<List<ConnectivityResult>>? connectivityStream,
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
          isOfflineProvider.overrideWith((ref) async => initiallyOffline),
          connectivityStreamProvider.overrideWith(
            (ref) =>
                connectivityStream ??
                const Stream<List<ConnectivityResult>>.empty(),
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
        await pumpErrorScreen(tester, onRetry: () async {});

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
        await pumpErrorScreen(tester, onRetry: () async {});

        expect(find.text('Try Joining Again'), findsOneWidget);
        expect(find.byType(OutlinedButton), findsOneWidget);
      });

      testWidgets('hides retry button when onRetry is null', (tester) async {
        await pumpErrorScreen(tester);

        expect(find.text('Try Joining Again'), findsNothing);
        expect(find.byType(OutlinedButton), findsNothing);
      });

      testWidgets('retry button invokes onRetry callback', (tester) async {
        var retryCount = 0;
        await pumpErrorScreen(tester, onRetry: () async => retryCount++);

        await tester.tap(find.text('Try Joining Again'));
        await tester.pump();

        expect(retryCount, 1);
      });
    });

    group('offline error', () {
      testWidgets('shows offline icon and connection guidance', (tester) async {
        await pumpErrorScreen(
          tester,
          onRetry: () async {},
          initiallyOffline: true,
        );

        expect(find.text("You're Offline"), findsOneWidget);
        expect(
          find.text(
            'Video sessions require an active internet connection.\n'
            'Check your Wi-Fi or mobile data, then tap below to rejoin.',
          ),
          findsOneWidget,
        );
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is TotemIcon && widget.icon == TotemIcons.wifiOff,
          ),
          findsOneWidget,
        );
        expect(find.text('Something went wrong'), findsNothing);
      });

      testWidgets('reacts to connectivity changes while visible', (
        tester,
      ) async {
        final connectivityChanges =
            StreamController<List<ConnectivityResult>>();
        addTearDown(connectivityChanges.close);

        await pumpErrorScreen(
          tester,
          onRetry: () async {},
          connectivityStream: connectivityChanges.stream,
        );
        expect(find.text('Something went wrong'), findsOneWidget);

        connectivityChanges.add(const [ConnectivityResult.none]);
        await tester.pumpAndSettle();
        expect(find.text("You're Offline"), findsOneWidget);

        connectivityChanges.add(const [ConnectivityResult.wifi]);
        await tester.pumpAndSettle();
        expect(find.text('Something went wrong'), findsOneWidget);
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
        await pumpErrorScreen(
          tester,
          error: wrappedError,
          onRetry: () async {},
        );

        expect(find.text('Something went wrong'), findsNothing);
      });
    });

    group('RoomErrorResponse notFound', () {
      const notFoundError = ApiError<JoinResponse, RoomErrorResponse>(
        statusCode: 404,
        error: RoomErrorResponse(
          code: ErrorCode.notFound,
          message: 'Session not found',
        ),
      );

      testWidgets('shows SessionDisconnectedScreen with other reason', (
        tester,
      ) async {
        await pumpErrorScreen(
          tester,
          error: notFoundError,
          onRetry: () async {},
        );

        expect(find.text('Something went wrong'), findsNothing);
        expect(find.byType(SessionDisconnectedScreen), findsOneWidget);
      });
    });
  });
}
