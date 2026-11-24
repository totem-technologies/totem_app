import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_core/auth/repositories/auth_repository.dart';
import 'package:totem_core/core/config/app_config.dart';
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/features/permissions/notification_permissions.dart';

part 'firebase_messaging_service.g.dart';

@Riverpod(keepAlive: true)
FirebaseMessagingService firebaseMessagingService(Ref ref) {
  final service = FirebaseMessagingService(
    authRepository: ref.read(authRepositoryProvider),
    messaging: FirebaseMessaging.instance,
    vapidKey: AppConfig.instance.vapidKey,
  );
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
}

/// Owns Firebase Messaging permission and authenticated installation lifecycle.
class FirebaseMessagingService implements NotificationPermissions {
  FirebaseMessagingService({
    required this.authRepository,
    required this.messaging,
    required this.vapidKey,
  });

  final AuthRepository authRepository;
  final FirebaseMessaging messaging;
  final String? vapidKey;
  StreamSubscription<String>? _fidSubscription;
  String? _registeredFid;
  String? _pendingFid;
  Future<void>? _pendingFidUpdate;
  Future<void>? _pendingRegistration;
  int? _registrationGeneration;
  Future<void>? _pendingUnregistration;
  int _sessionGeneration = 0;
  bool _endingSession = false;
  bool _disposed = false;
  bool _sessionAuthenticated = false;
  bool Function()? _isAuthenticated;

  @override
  Future<void> request() async {
    try {
      await messaging.requestPermission(provisional: true);
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to request notification permissions',
      );
    }
  }

  void start({required bool Function() isAuthenticated}) {
    if (_disposed) return;
    _isAuthenticated = isAuthenticated;
    try {
      _fidSubscription ??= messaging.onRegistered.listen(
        _onRegistered,
        onError: (dynamic error, StackTrace stackTrace) {
          ErrorHandler.logError(
            error,
            stackTrace: stackTrace,
            message: 'FID stream update failed',
          );
        },
      );
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to initialize FCM token listener',
      );
    }
  }

  void beginSession() {
    if (_disposed) return;
    _sessionAuthenticated = true;
    _endingSession = false;
  }

  void register() {
    if (_disposed ||
        _endingSession ||
        !(_isAuthenticated?.call() ?? false) ||
        _fidSubscription == null) {
      return;
    }
    if (_pendingRegistration != null &&
        _registrationGeneration == _sessionGeneration) {
      return;
    }
    final generation = _sessionGeneration;
    final previousUnregistration = _pendingUnregistration;
    final registration = () async {
      try {
        if (previousUnregistration != null) await previousUnregistration;
        if (_disposed || generation != _sessionGeneration || _endingSession) {
          return;
        }
        await messaging.register(vapidKey: vapidKey);
      } catch (error, stackTrace) {
        ErrorHandler.logError(
          error,
          stackTrace: stackTrace,
          message: 'FCM registration failed',
        );
      }
    }();
    _pendingRegistration = registration;
    _registrationGeneration = generation;
    unawaited(
      registration.whenComplete(() {
        if (identical(_pendingRegistration, registration)) {
          _pendingRegistration = null;
        }
      }),
    );
  }

  void beginEndingSession() {
    _endingSession = true;
    _sessionGeneration++;
  }

  Future<void> unregister() async {
    try {
      await _pendingFidUpdate?.timeout(const Duration(seconds: 5));
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'FID registration did not finish before logout',
      );
    }
    final fid = _registeredFid;
    _registeredFid = null;
    _pendingFid = null;
    if (fid != null && _sessionAuthenticated) {
      try {
        await authRepository
            .unregisterFid(fid)
            .timeout(const Duration(seconds: 5));
      } catch (error, stackTrace) {
        ErrorHandler.logError(
          error,
          stackTrace: stackTrace,
          message: 'FID removal failed',
        );
      }
    }
    final registration = _pendingRegistration;
    final previousUnregistration = _pendingUnregistration;
    final unregistration = () async {
      try {
        await previousUnregistration;
        await registration;
        await messaging.unregister();
      } catch (error, stackTrace) {
        ErrorHandler.logError(
          error,
          stackTrace: stackTrace,
          message: 'FCM unregistration failed',
        );
      }
    }();
    _pendingUnregistration = unregistration;
    unawaited(
      unregistration.whenComplete(() {
        if (identical(_pendingUnregistration, unregistration)) {
          _pendingUnregistration = null;
        }
      }),
    );
    try {
      await unregistration.timeout(const Duration(seconds: 5));
    } on TimeoutException catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'FCM unregistration timed out',
      );
    }
  }

  void _onRegistered(String fid) {
    if (_disposed || _endingSession || !(_isAuthenticated?.call() ?? false)) {
      return;
    }
    if (fid == _registeredFid || fid == _pendingFid) return;
    _pendingFid = fid;
    final previousUpdate = _pendingFidUpdate;
    final generation = _sessionGeneration;
    final update = () async {
      try {
        await previousUpdate;
        if (_disposed ||
            generation != _sessionGeneration ||
            _endingSession ||
            !(_isAuthenticated?.call() ?? false)) {
          return;
        }
        await authRepository.registerFid(fid);
        if (!_disposed &&
            (generation == _sessionGeneration ||
                (_endingSession && _isAuthenticated != null))) {
          _registeredFid = fid;
        }
      } catch (error, stackTrace) {
        ErrorHandler.logError(
          error,
          stackTrace: stackTrace,
          message: 'FID registration failed',
        );
      } finally {
        if (_pendingFid == fid) _pendingFid = null;
      }
    }();
    _pendingFidUpdate = update;
  }

  Future<void> detach() async {
    _sessionGeneration++;
    _endingSession = true;
    _isAuthenticated = null;
    _pendingFid = null;
    _registeredFid = null;
    final subscription = _fidSubscription;
    _fidSubscription = null;
    await subscription?.cancel();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await detach();
  }
}
