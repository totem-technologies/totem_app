import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:checks/checks.dart';
import 'package:mocktail/mocktail.dart';
import 'package:totem_app/features/auth/services/firebase_messaging_service.dart';
import 'package:totem_core/auth/repositories/auth_repository.dart';
import 'package:totem_core/core/config/app_config.dart';
import 'package:totem_core/core/errors/app_exceptions.dart';
import 'package:totem_core/core/errors/error_handler.dart';

class _MockFirebaseMessaging extends Mock implements FirebaseMessaging {}

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockFirebaseMessaging messaging;
  late FirebaseMessagingService service;

  setUp(() {
    AppConfig.instance = AppConfig.parse(
      'ENVIRONMENT=development\nAPI_URL=https://example.test\n'
      'LIVEKIT_URL=wss://example.test',
    );
    messaging = _MockFirebaseMessaging();
    service = FirebaseMessagingService(
      authRepository: _MockAuthRepository(),
      messaging: messaging,
      vapidKey: null,
    );
  });

  test(
    'keeps known APNs, network, permission, and unsupported failures local',
    () async {
      final reported = <Object>[];
      service = FirebaseMessagingService(
        authRepository: _MockAuthRepository(),
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
