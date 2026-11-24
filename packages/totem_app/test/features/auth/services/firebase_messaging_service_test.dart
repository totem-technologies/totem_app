import 'dart:async';

import 'package:checks/checks.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:totem_app/features/auth/services/firebase_messaging_service.dart';
import 'package:totem_core/auth/repositories/auth_repository.dart';
import 'package:totem_core/core/config/app_config.dart';
import 'package:totem_core/core/errors/app_exceptions.dart';
import 'package:totem_core/core/errors/error_handler.dart';

class _MockFirebaseMessaging extends Mock implements FirebaseMessaging {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockConnectivity extends Mock implements Connectivity {}

void main() {
  late _MockFirebaseMessaging messaging;
  late _MockAuthRepository authRepository;
  late _MockConnectivity connectivity;
  late StreamController<String> registeredFids;
  late StreamController<List<ConnectivityResult>> connectivityChanges;
  late FirebaseMessagingService service;
  var authenticated = true;

  setUp(() {
    AppConfig.instance = AppConfig.parse(
      'ENVIRONMENT=development\nAPI_URL=https://example.test\n'
      'LIVEKIT_URL=wss://example.test',
    );
    messaging = _MockFirebaseMessaging();
    authRepository = _MockAuthRepository();
    connectivity = _MockConnectivity();
    registeredFids = StreamController<String>.broadcast();
    connectivityChanges =
        StreamController<List<ConnectivityResult>>.broadcast();
    authenticated = true;
    when(() => messaging.onRegistered).thenAnswer((_) => registeredFids.stream);
    when(
      () => connectivity.onConnectivityChanged,
    ).thenAnswer((_) => connectivityChanges.stream);
    when(() => messaging.register(vapidKey: null)).thenAnswer((_) async {});
    when(() => messaging.unregister()).thenAnswer((_) async {});
    service = FirebaseMessagingService(
      authRepository: authRepository,
      messaging: messaging,
      vapidKey: null,
      connectivity: connectivity,
    );
  });

  tearDown(() async {
    await service.dispose();
    await registeredFids.close();
    await connectivityChanges.close();
  });

  void startService() {
    service.start(isAuthenticated: () => authenticated);
    service.beginSession();
  }

  test('retries transient native registration and then succeeds', () {
    fakeAsync((async) {
      var attempts = 0;
      when(() => messaging.register(vapidKey: null)).thenAnswer((_) async {
        attempts++;
        if (attempts == 1) {
          throw FirebaseException(
            plugin: 'firebase_messaging',
            code: 'apns-token-not-set',
          );
        }
      });

      startService();
      service.register();
      async.flushMicrotasks();
      async.elapse(const Duration(days: 1));
      async.flushMicrotasks();

      check(attempts).equals(2);
      verify(() => messaging.register(vapidKey: null)).called(2);
    });
  });

  test('retries backend FID sync without repeating native registration', () {
    fakeAsync((async) {
      var syncAttempts = 0;
      when(() => authRepository.registerFid('fid-1')).thenAnswer((_) async {
        syncAttempts++;
        if (syncAttempts == 1) {
          throw AppNetworkException(
            'Temporary backend failure',
            code: 'SERVER_ERROR_503',
          );
        }
      });

      startService();
      registeredFids.add('fid-1');
      async.flushMicrotasks();
      async.elapse(const Duration(days: 1));
      async.flushMicrotasks();

      check(syncAttempts).equals(2);
      verifyNever(() => messaging.register(vapidKey: null));
    });
  });

  test('bounds transient native registration retries', () {
    fakeAsync((async) {
      var attempts = 0;
      when(() => messaging.register(vapidKey: null)).thenAnswer((_) async {
        attempts++;
        throw FirebaseException(
          plugin: 'firebase_messaging',
          code: 'network-request-failed',
        );
      });

      startService();
      service.register();
      async.flushMicrotasks();
      async.elapse(const Duration(days: 1));
      async.flushMicrotasks();

      check(attempts).equals(4);
    });
  });

  test('logout cancels a pending native registration retry', () {
    fakeAsync((async) {
      var attempts = 0;
      when(() => messaging.register(vapidKey: null)).thenAnswer((_) async {
        attempts++;
        throw FirebaseException(
          plugin: 'firebase_messaging',
          code: 'network-error',
        );
      });

      startService();
      service.register();
      async.flushMicrotasks();
      service.beginEndingSession();
      async.elapse(const Duration(days: 1));
      async.flushMicrotasks();

      check(attempts).equals(1);
    });
  });

  test('removes the previous FID only after the rotated FID is confirmed', () {
    fakeAsync((async) {
      final newFidRegistration = Completer<void>();
      when(
        () => authRepository.registerFid('fid-old'),
      ).thenAnswer((_) async {});
      when(
        () => authRepository.registerFid('fid-new'),
      ).thenAnswer((_) => newFidRegistration.future);

      startService();
      registeredFids.add('fid-old');
      async.flushMicrotasks();
      registeredFids.add('fid-new');
      async.flushMicrotasks();

      verifyNever(() => authRepository.unregisterFid('fid-old'));
      newFidRegistration.complete();
      async.flushMicrotasks();

      verify(() => authRepository.unregisterFid('fid-old')).called(1);
    });
  });

  test('keeps the previous FID when rotation registration fails', () {
    fakeAsync((async) {
      when(
        () => authRepository.registerFid('fid-old'),
      ).thenAnswer((_) async {});
      when(
        () => authRepository.registerFid('fid-new'),
      ).thenThrow(StateError('backend registration failed'));

      startService();
      registeredFids.add('fid-old');
      async.flushMicrotasks();
      registeredFids.add('fid-new');
      async.flushMicrotasks();

      verify(() => authRepository.registerFid('fid-old')).called(1);
      verify(() => authRepository.registerFid('fid-new')).called(1);
      verifyNever(() => authRepository.unregisterFid('fid-old'));
    });
  });

  test('reports unexpected FID registration once with sanitized error', () {
    fakeAsync((async) {
      final reported = <Object>[];
      service = FirebaseMessagingService(
        authRepository: authRepository,
        messaging: messaging,
        vapidKey: null,
        errorReporter: (error, stackTrace, message, incidentKey) {
          reported.add(error);
        },
      );
      when(
        () => authRepository.registerFid('fid-secret'),
      ).thenThrow(StateError('failed for fid-secret'));

      startService();
      registeredFids.add('fid-secret');
      async.flushMicrotasks();

      check(reported).length.equals(1);
      check(reported.single.toString()).not((it) => it.contains('fid-secret'));
    });
  });

  test('does not report failed FID unregistration to Sentry', () {
    final reported = <Object>[];
    final error = AppNetworkException('Offline', code: 'NO_CONNECTION');
    service = FirebaseMessagingService(
      authRepository: authRepository,
      messaging: messaging,
      vapidKey: null,
      errorReporter: (error, stackTrace, message, incidentKey) {
        reported.add(error);
      },
    );
    when(() => authRepository.registerFid('fid-1')).thenAnswer((_) async {});
    when(() => authRepository.unregisterFid('fid-1')).thenThrow(error);

    fakeAsync((async) {
      startService();
      registeredFids.add('fid-1');
      async.flushMicrotasks();
      unawaited(service.unregister());
      async.flushMicrotasks();

      check(reported).isEmpty();
      check(ErrorHandler.wasReported(error)).isFalse();
    });
  });

  test('reports unexpected FID unregistration with a sanitized error', () {
    final reported = <Object>[];
    final error = StateError('failed for fid-secret');
    service = FirebaseMessagingService(
      authRepository: authRepository,
      messaging: messaging,
      vapidKey: null,
      errorReporter: (error, stackTrace, message, incidentKey) {
        reported.add(error);
      },
    );
    when(
      () => authRepository.registerFid('fid-secret'),
    ).thenAnswer((_) async {});
    when(() => authRepository.unregisterFid('fid-secret')).thenThrow(error);

    fakeAsync((async) {
      startService();
      registeredFids.add('fid-secret');
      async.flushMicrotasks();
      unawaited(service.unregister());
      async.flushMicrotasks();

      check(reported).length.equals(1);
      check(reported.single.toString()).not((it) => it.contains('fid-secret'));
    });
  });

  test('reports unexpected native FCM unregistration failures', () {
    fakeAsync((async) {
      final reported = <Object>[];
      final error = StateError('native unregistration failed');
      service = FirebaseMessagingService(
        authRepository: authRepository,
        messaging: messaging,
        vapidKey: null,
        errorReporter: (error, stackTrace, message, incidentKey) {
          reported.add(error);
        },
      );
      when(() => messaging.unregister()).thenThrow(error);

      unawaited(service.unregister());
      async.flushMicrotasks();

      check(reported).deepEquals([error]);
    });
  });

  test('uses a connectivity recovery to retry backend FID sync', () {
    fakeAsync((async) {
      var syncAttempts = 0;
      when(() => authRepository.registerFid('fid-1')).thenAnswer((_) async {
        syncAttempts++;
        if (syncAttempts == 1) {
          throw AppNetworkException(
            'Temporary backend failure',
            code: 'SERVER_ERROR_503',
          );
        }
      });

      startService();
      registeredFids.add('fid-1');
      async.flushMicrotasks();
      connectivityChanges.add([ConnectivityResult.none]);
      async.flushMicrotasks();
      connectivityChanges.add([ConnectivityResult.wifi]);
      async.flushMicrotasks();

      check(syncAttempts).equals(2);
      verifyNever(() => messaging.register(vapidKey: null));
    });
  });

  test(
    'keeps known APNs, network, permission, and unsupported failures local',
    () async {
      final reported = <Object>[];
      service = FirebaseMessagingService(
        authRepository: authRepository,
        messaging: messaging,
        vapidKey: null,
        errorReporter: (error, stackTrace, message, incidentKey) {
          reported.add(error);
        },
      );
      for (final code in [
        'apns-token-not-set',
        'network-request-failed',
        'permission-denied',
        'network-error',
        'not-implemented',
        'unsupported',
        'unavailable',
      ]) {
        final error = FirebaseException(
          plugin: 'firebase_messaging',
          code: code,
        );
        when(
          () => messaging.requestPermission(provisional: true),
        ).thenThrow(error);

        await service.request();

        check(ErrorHandler.wasReported(error)).isFalse();
      }
      check(reported).isEmpty();
    },
  );

  test('reports missing FID configuration and unknown failures', () async {
    for (final error in [
      FirebaseException(plugin: 'firebase_messaging', code: 'missing-fid'),
      FirebaseException(
        plugin: 'firebase_installations',
        code: 'network-request-failed',
      ),
      AppNetworkException('Backend HTTP failure', code: 'HTTP_ERROR_503'),
      StateError('unexpected programming failure'),
    ]) {
      when(
        () => messaging.requestPermission(provisional: true),
      ).thenThrow(error);

      await service.request();

      check(ErrorHandler.wasReported(error)).isTrue();
      check(ErrorHandler.logError(error)).isFalse();
    }
  });
}
