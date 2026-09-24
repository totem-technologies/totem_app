import 'dart:async';

import 'package:checks/checks.dart';
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

        check(tester.takeException()).isNull();
        check(
          tester.widgetList(find.byType(CustomScrollView)),
        ).length.equals(1);
        check(
          tester
              .state<ScrollableState>(find.byType(Scrollable))
              .position
              .maxScrollExtent,
        ).equals(0);

        await tester.drag(find.byType(CustomScrollView), const Offset(0, -100));
        await tester.pumpAndSettle();

        check(
          tester
              .state<ScrollableState>(find.byType(Scrollable))
              .position
              .pixels,
        ).equals(0);
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

        check(tester.takeException()).isNull();
        final scrollable = tester.state<ScrollableState>(
          find.byType(Scrollable),
        );
        check(scrollable.position.maxScrollExtent).isGreaterThan(0);

        await tester.drag(find.byType(CustomScrollView), const Offset(0, -100));
        await tester.pumpAndSettle();

        check(scrollable.position.pixels).isGreaterThan(0);
        check(
          tester.widgetList(find.text('Go back to Session Details')),
        ).length.equals(1);
      });
    });

    group('generic error (no RoomErrorResponse)', () {
      testWidgets('shows retry button when onRetry is provided', (
        tester,
      ) async {
        await pumpErrorScreen(tester, onRetry: () async {});

        check(
          tester.widgetList(find.text('Try Joining Again')),
        ).length.equals(1);
        check(
          tester.widgetList(find.byType(ConfirmationDialogButton)),
        ).length.equals(1);
      });

      testWidgets('hides retry button when onRetry is null', (tester) async {
        await pumpErrorScreen(tester);

        check(
          tester.widgetList(find.text('Try Joining Again')),
        ).length.equals(0);
        check(
          tester.widgetList(find.byType(ConfirmationDialogButton)),
        ).length.equals(0);
      });

      testWidgets('retry button invokes onRetry callback', (tester) async {
        var retryCount = 0;
        await pumpErrorScreen(tester, onRetry: () async => retryCount++);

        await tester.tap(find.text('Try Joining Again'));
        await tester.pump();

        check(retryCount).equals(1);
      });
    });

    group('offline error', () {
      testWidgets('shows offline icon and connection guidance', (tester) async {
        await pumpErrorScreen(
          tester,
          onRetry: () async {},
          initiallyOffline: true,
        );

        check(tester.widgetList(find.text("You're Offline"))).length.equals(1);
        check(
          tester.widgetList(
            find.text(
              'Video sessions require an active internet connection.\n'
              'Check your Wi-Fi or mobile data, then tap below to rejoin.',
            ),
          ),
        ).length.equals(1);
        check(
          tester.widgetList(
            find.byWidgetPredicate(
              (widget) =>
                  widget is TotemIcon && widget.icon == TotemIcons.wifiOff,
            ),
          ),
        ).length.equals(1);
        check(
          tester.widgetList(find.text('Something went wrong')),
        ).length.equals(0);
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
        check(
          tester.widgetList(find.text('Something went wrong')),
        ).length.equals(1);

        connectivityChanges.add(true);
        await tester.pumpAndSettle();
        check(tester.widgetList(find.text("You're Offline"))).length.equals(1);

        connectivityChanges.add(false);
        await tester.pumpAndSettle();
        check(
          tester.widgetList(find.text('Something went wrong')),
        ).length.equals(1);
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

      testWidgets('unwraps the API error into the ended-session state', (
        tester,
      ) async {
        await pumpErrorScreen(
          tester,
          error: wrappedError,
          onRetry: () async {},
        );

        check(
          tester.widgetList(find.byType(SessionDisconnectedScreen)),
        ).length.equals(1);
        check(
          tester.widgetList(find.text('Something went wrong')),
        ).length.equals(0);
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

        check(
          tester.widgetList(find.text('Something went wrong')),
        ).length.equals(0);
        check(
          tester.widgetList(find.byType(SessionDisconnectedScreen)),
        ).length.equals(1);
      });
    });
  });
}
