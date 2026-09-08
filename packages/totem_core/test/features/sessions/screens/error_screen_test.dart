import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/repositories/space_repository.dart';
import 'package:totem_core/core/services/connectivity_service.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/screens/error_screen.dart';
import 'package:totem_core/features/sessions/screens/session_disconnected.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/confirmation_dialog.dart';

void main() {
  Future<void> pumpErrorScreen(
    WidgetTester tester, {
    AsyncCallback? onRetry,
    Object? error,
    bool initiallyOffline = false,
    Stream<bool>? connectivityStream,
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
          isOfflineProvider.overrideWith(
            (ref) => connectivityStream ?? Stream.value(initiallyOffline),
          ),
        ],
        child: MaterialApp(
          home: SessionErrorScreen(onRetry: onRetry, error: error),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
  }

  group('RoomErrorScreen', () {
    group('layout', () {
      testWidgets('keeps the portrait layout fitted without scrolling', (
        tester,
      ) async {
        tester.view
          ..physicalSize = const Size(390, 844)
          ..devicePixelRatio = 1;
        addTearDown(() {
          tester.view
            ..resetPhysicalSize()
            ..resetDevicePixelRatio();
        });

        await pumpErrorScreen(
          tester,
          onRetry: () async {},
          initiallyOffline: true,
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(CustomScrollView), findsOneWidget);
        expect(
          tester
              .state<ScrollableState>(find.byType(Scrollable))
              .position
              .maxScrollExtent,
          0,
        );

        await tester.drag(find.byType(CustomScrollView), const Offset(0, -100));
        await tester.pumpAndSettle();

        expect(
          tester
              .state<ScrollableState>(find.byType(Scrollable))
              .position
              .pixels,
          0,
        );
      });

      testWidgets('scrolls instead of overflowing in short landscape', (
        tester,
      ) async {
        tester.view
          ..physicalSize = const Size(844, 390)
          ..devicePixelRatio = 1;
        addTearDown(() {
          tester.view
            ..resetPhysicalSize()
            ..resetDevicePixelRatio();
        });

        await pumpErrorScreen(
          tester,
          onRetry: () async {},
          initiallyOffline: true,
        );

        expect(tester.takeException(), isNull);
        final scrollable = tester.state<ScrollableState>(
          find.byType(Scrollable),
        );
        expect(scrollable.position.maxScrollExtent, greaterThan(0));

        await tester.drag(find.byType(CustomScrollView), const Offset(0, -100));
        await tester.pumpAndSettle();

        expect(scrollable.position.pixels, greaterThan(0));
        expect(find.text('Go back to Session Details'), findsOneWidget);
      });
    });

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
        expect(find.byType(ConfirmationDialogButton), findsOneWidget);
      });

      testWidgets('hides retry button when onRetry is null', (tester) async {
        await pumpErrorScreen(tester);

        expect(find.text('Try Joining Again'), findsNothing);
        expect(find.byType(ConfirmationDialogButton), findsNothing);
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
        final connectivityChanges = StreamController<bool>();
        addTearDown(connectivityChanges.close);

        await pumpErrorScreen(
          tester,
          onRetry: () async {},
          connectivityStream: connectivityChanges.stream,
        );
        expect(find.text('Something went wrong'), findsOneWidget);

        connectivityChanges.add(true);
        await tester.pumpAndSettle();
        expect(find.text("You're Offline"), findsOneWidget);

        connectivityChanges.add(false);
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
