import 'dart:async';

import 'package:checks/checks.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride, TargetPlatform;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:totem_app/features/auth/services/notifications_service.dart';

import 'package:totem_app/features/spaces/screens/session_deep_link_screen.dart';
import 'package:totem_core/core/api/api_client/models/session_notification_payload.dart';
import 'package:totem_core/core/repositories/space_repository.dart';
import 'package:totem_core/shared/router.dart';
import 'package:totem_core/shared/widgets/error_screen.dart';

class _RouterFake extends TotemRouter {
  _RouterFake();

  final key = GlobalKey<NavigatorState>();
  HomeRoutes? homeRoute;

  @override
  GlobalKey<NavigatorState> get navigatorKey => key;

  @override
  Uri get baseUri => Uri.parse('https://test.example');

  @override
  void popOrHome([BuildContext? context]) {}

  @override
  void toHome([HomeRoutes route = HomeRoutes.initialRoute]) =>
      homeRoute = route;

  @override
  Future<void> toKeeperProfile(BuildContext context, String userSlug) async {}

  @override
  Future<void> toSpaceSession(
    BuildContext context,
    String spaceSlug,
    String? sessionSlug, [
    bool replacement = false,
  ]) async {}

  @override
  GoRouter createRouter(WidgetRef ref) => throw UnimplementedError();

  @override
  void setTabCloseConfirmationEnabled(bool enabled) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'false/null initialization results are silent and not retried',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const channel = MethodChannel(
        'dexterous.com/flutter/local_notifications',
      );
      final previousPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() {
        messenger.setMockMethodCallHandler(channel, null);
        debugDefaultTargetPlatformOverride = previousPlatform;
      });

      for (final result in <bool?>[false, null]) {
        debugDefaultTargetPlatformOverride = result == null
            ? TargetPlatform.iOS
            : TargetPlatform.android;
        if (result == null) {
          IOSFlutterLocalNotificationsPlugin.registerWith();
        } else {
          AndroidFlutterLocalNotificationsPlugin.registerWith();
        }
        var initializeCalls = 0;
        final initializeStarted = Completer<void>();
        final initializationResult = Completer<bool?>();
        final reported = <String>[];
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'initialize') {
            initializeCalls++;
            if (!initializeStarted.isCompleted) initializeStarted.complete();
            return initializationResult.future;
          }
          return null;
        });
        SharedPreferences.setMockInitialValues({});
        final service = NotificationsService.forTesting(
          permissionReader: () async => AuthorizationStatus.denied,
          errorReporter: (_, _, message) => reported.add(message),
        );

        final firstInitialization = service.initialize();
        final concurrentInitialization = service.initialize();
        await initializeStarted.future;
        check(initializeCalls).equals(1);
        initializationResult.complete(result);
        await Future.wait([firstInitialization, concurrentInitialization]);
        await service.initialize();

        check(initializeCalls).equals(1);
        check(reported).isEmpty();
      }
    },
  );

  testWidgets(
    'permission grant on resume retries local init and enables display',
    (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const channel = MethodChannel(
        'dexterous.com/flutter/local_notifications',
      );
      final previousPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      addTearDown(() {
        messenger.setMockMethodCallHandler(channel, null);
        debugDefaultTargetPlatformOverride = previousPlatform;
      });

      var authorizationStatus = AuthorizationStatus.denied;
      var initializeCalls = 0;
      var showCalls = 0;
      final retryStarted = Completer<void>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'initialize':
            initializeCalls++;
            if (initializeCalls == 2 && !retryStarted.isCompleted) {
              retryStarted.complete();
            }
            return initializeCalls > 1;
          case 'getNotificationAppLaunchDetails':
            return {'notificationLaunchedApp': false};
          case 'show':
            showCalls++;
            return null;
        }
        return null;
      });
      SharedPreferences.setMockInitialValues({});
      final service = NotificationsService.forTesting(
        permissionReader: () async => authorizationStatus,
        errorReporter: (_, _, message) => fail(message),
      );

      await service.initialize();
      await service.showNotification(
        title: 'title',
        body: 'body',
        payload: const SessionNotificationPayload(
          type: NotificationType.sessionStarting,
          spaceSlug: 'space',
          sessionSlug: 'session',
        ),
      );
      check(showCalls).equals(0);

      authorizationStatus = AuthorizationStatus.authorized;
      service.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await retryStarted.future;
      await tester.pump();
      await service.showNotification(
        title: 'title',
        body: 'body',
        payload: const SessionNotificationPayload(
          type: NotificationType.sessionStarting,
          spaceSlug: 'space',
          sessionSlug: 'session',
        ),
      );

      service.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();
      check(initializeCalls).equals(2);
      check(showCalls).equals(1);
    },
  );

  test(
    'an overlapping permission refresh rechecks after the stale result',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const channel = MethodChannel(
        'dexterous.com/flutter/local_notifications',
      );
      final previousPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      addTearDown(() {
        messenger.setMockMethodCallHandler(channel, null);
        debugDefaultTargetPlatformOverride = previousPlatform;
      });

      final staleRefresh = Completer<AuthorizationStatus>();
      var authorizationStatus = AuthorizationStatus.denied;
      var permissionReads = 0;
      var showCalls = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getNotificationAppLaunchDetails') {
          return {'notificationLaunchedApp': false};
        }
        if (call.method == 'show') {
          showCalls++;
          return null;
        }
        return true;
      });
      SharedPreferences.setMockInitialValues({});
      final service = NotificationsService.forTesting(
        permissionReader: () {
          permissionReads++;
          if (permissionReads == 2) return staleRefresh.future;
          return Future.value(authorizationStatus);
        },
        errorReporter: (_, _, message) => fail(message),
      );
      await service.initialize();

      service.didChangeAppLifecycleState(AppLifecycleState.resumed);
      authorizationStatus = AuthorizationStatus.authorized;
      final permissionAfterRequest = service.refreshPermissionStatus();
      staleRefresh.complete(AuthorizationStatus.denied);
      await permissionAfterRequest;
      await service.showNotification(
        title: 'title',
        body: 'body',
        payload: const SessionNotificationPayload(
          type: NotificationType.sessionStarting,
          spaceSlug: 'space',
          sessionSlug: 'session',
        ),
      );

      check(permissionReads).equals(3);
      check(showCalls).equals(1);
    },
  );

  test(
    'foreground notification without a session payload is displayed',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const channel = MethodChannel(
        'dexterous.com/flutter/local_notifications',
      );
      final previousPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      final showCalls = <Map<Object?, Object?>>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getNotificationAppLaunchDetails') {
          return {'notificationLaunchedApp': false};
        }
        if (call.method == 'show') {
          showCalls.add(Map<Object?, Object?>.from(call.arguments as Map));
          return null;
        }
        return true;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(channel, null);
        debugDefaultTargetPlatformOverride = previousPlatform;
      });

      SharedPreferences.setMockInitialValues({});
      final service = NotificationsService.forTesting(
        permissionReader: () async => AuthorizationStatus.authorized,
        errorReporter: (_, _, message) => fail(message),
      );
      await service.initialize();

      await service.showNotification(title: 'title', body: 'body');

      check(showCalls).length.equals(1);
      check(showCalls.single['title']).equals('title');
      check(showCalls.single['body']).equals('body');
      check(showCalls.single['payload']).equals('');
    },
  );

  test('unexpected local presentation errors are reported', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');
    final previousPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getNotificationAppLaunchDetails') {
        return {'notificationLaunchedApp': false};
      }
      if (call.method == 'show') {
        throw PlatformException(code: 'permissionDenied');
      }
      return true;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = previousPlatform;
    });

    final reported = <String>[];
    SharedPreferences.setMockInitialValues({});
    final service = NotificationsService.forTesting(
      permissionReader: () async => AuthorizationStatus.authorized,
      errorReporter: (_, _, message) => reported.add(message),
    );
    await service.initialize();

    await service.showNotification(
      title: 'title',
      body: 'body',
      payload: const SessionNotificationPayload(
        type: NotificationType.sessionStarting,
        spaceSlug: 'space',
        sessionSlug: 'session',
      ),
    );

    check(reported).deepEquals(['Failed to display local notification']);
  });

  test('unexpected local initialization errors are reported', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');
    final previousPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'initialize') {
        throw PlatformException(code: 'plugin_failure');
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = previousPlatform;
    });

    final reported = <String>[];
    SharedPreferences.setMockInitialValues({});
    final service = NotificationsService.forTesting(
      permissionReader: () async => AuthorizationStatus.denied,
      errorReporter: (_, _, message) => reported.add(message),
    );

    await service.initialize();

    check(reported).deepEquals(['Failed to initialize local notifications']);
  });

  test(
    'background notification payload is persisted for the next app launch',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();

      await notificationTapBackground(
        const NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          id: 1,
          payload:
              '{"payload":{"type":"session_starting","space_slug":"space","session_slug":"event"},"message_id":"message-1"}',
        ),
      );

      await preferences.reload();
      check(preferences.getString('initial_payload')).equals(
        '{"payload":{"type":"session_starting","space_slug":"space","session_slug":"event"},"message_id":"message-1"}',
      );
      check(
        preferences.getString('initial_payload_identity'),
      ).equals('message:message-1');
      check(preferences.getInt('initial_payload_timestamp')).isNotNull();
    },
  );

  test(
    'background notification with no payload clears stale interaction',
    () async {
      SharedPreferences.setMockInitialValues({
        'initial_payload': 'existing',
        'initial_payload_identity': 'local:1',
        'initial_payload_timestamp': 1,
      });

      await notificationTapBackground(
        const NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          id: 1,
        ),
      );

      final preferences = await SharedPreferences.getInstance();
      check(preferences.getString('initial_payload')).isNull();
      check(preferences.getString('initial_payload_identity')).isNull();
      check(preferences.getInt('initial_payload_timestamp')).isNull();
    },
  );

  test('oversized background payload is not persisted', () async {
    SharedPreferences.setMockInitialValues({});

    await notificationTapBackground(
      NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        id: 1,
        payload: List.filled(8193, 'x').join(),
      ),
    );

    final preferences = await SharedPreferences.getInstance();
    check(preferences.getString('initial_payload')).isNull();
  });

  testWidgets(
    'a malformed session deep link shows an error with home recovery',
    (tester) async {
      final router = _RouterFake();
      TotemRouter.instance = router;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider('missing-session').overrideWith(
              (ref) async => throw StateError('invalid session payload'),
            ),
          ],
          child: const MaterialApp(
            home: SessionDeepLinkScreen(sessionSlug: 'missing-session'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });

      check(tester.widgetList(find.byType(ErrorScreen))).length.equals(1);
      check(router.homeRoute).isNull();
    },
  );
}
