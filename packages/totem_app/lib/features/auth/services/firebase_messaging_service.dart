import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_core/auth/repositories/auth_repository.dart';
import 'package:totem_core/core/config/app_config.dart';
import 'package:totem_core/core/errors/app_exceptions.dart';
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/core/services/connectivity_service.dart';
import 'package:totem_core/shared/logger.dart';
import 'package:totem_core/features/permissions/notification_permissions.dart';

part 'firebase_messaging_service.g.dart';

const _maxRecoveryRetries = 3;

Duration _recoveryDelay(int retry) => Duration(seconds: 1 << (retry - 1));

bool _isTransientBackendError(Object error) {
  if (error is TimeoutException) return true;
  if (error is! AppNetworkException) return false;
  final code = error.code;
  return code == 'NO_CONNECTION' ||
      code == 'TIMEOUT' ||
      code == 'NETWORK_ERROR' ||
      code?.startsWith('SERVER_ERROR_5') == true;
}

bool _isTransientRegistrationError(Object error) {
  final code = switch (error) {
    FirebaseException(plugin: 'firebase_messaging') => error.code,
    PlatformException() => error.code,
    _ => null,
  };
  return code == 'apns-token-not-set' ||
      code == 'network-request-failed' ||
      code == 'network-error' ||
      code == 'unavailable';
}

bool _isExpectedMessagingError(Object error) {
  final code = switch (error) {
    FirebaseException(plugin: 'firebase_messaging') => error.code,
    PlatformException() => error.code,
    _ => null,
  };

  return switch (code) {
    'apns-token-not-set' ||
    'network-request-failed' ||
    'network-error' ||
    'permission-denied' ||
    'not-implemented' ||
    'unsupported' ||
    'unavailable' => true,
    _ => false,
  };
}

typedef MessagingErrorReporter =
    void Function(
      Object error,
      StackTrace stackTrace,
      String message,
      String incidentKey,
    );

@Riverpod(keepAlive: true)
FirebaseMessagingService firebaseMessagingService(Ref ref) {
  final service = FirebaseMessagingService(
    authRepository: ref.read(authRepositoryProvider),
    messaging: FirebaseMessaging.instance,
    vapidKey: AppConfig.instance.vapidKey,
    connectivity: ref.read(connectivityProvider),
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
    this.errorReporter,
    this.connectivity,
  });

  final AuthRepository authRepository;
  final FirebaseMessaging messaging;
  final String? vapidKey;
  final MessagingErrorReporter? errorReporter;
  final Connectivity? connectivity;
  StreamSubscription<String>? _fidSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  String? _retryFid;
  String? _latestFid;
  Timer? _registrationRetryTimer;
  Timer? _fidRetryTimer;
  int _registrationRetries = 0;
  int _fidRetries = 0;
  int? _fidRetryGeneration;
  bool? _wasOffline;
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

  void _handleFidError(
    Object error, {
    required StackTrace stackTrace,
    required String message,
    required String operation,
  }) {
    if (_isTransientBackendError(error)) {
      logger.d(message);
      return;
    }

    final safeError = StateError('$message (${error.runtimeType})');
    final incidentKey = 'firebase-messaging:$operation:${error.runtimeType}';
    final reporter = errorReporter;
    if (reporter != null) {
      reporter(safeError, stackTrace, message, incidentKey);
    } else {
      ErrorHandler.report(
        safeError,
        stackTrace: stackTrace,
        message: message,
        incidentKey: incidentKey,
      );
    }
  }

  void _handleMessagingError(
    Object error, {
    required StackTrace stackTrace,
    required String message,
    required String operation,
  }) {
    if (error is TimeoutException || _isExpectedMessagingError(error)) {
      logger.d(message);
      return;
    }

    final incidentKey = 'firebase-messaging:$operation:${error.runtimeType}';
    final reporter = errorReporter;
    if (reporter != null) {
      reporter(error, stackTrace, message, incidentKey);
    } else {
      ErrorHandler.report(
        error,
        stackTrace: stackTrace,
        message: message,
        incidentKey: incidentKey,
      );
    }
  }

  @override
  Future<void> request() async {
    try {
      await messaging.requestPermission(provisional: true);
    } catch (error, stackTrace) {
      _handleMessagingError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to request notification permissions',
        operation: 'request-permission',
      );
    }
  }

  void start({required bool Function() isAuthenticated}) {
    if (_disposed) return;
    _isAuthenticated = isAuthenticated;
    _connectivitySubscription ??= connectivity?.onConnectivityChanged.listen((
      results,
    ) {
      final isOffline = isOfflineConnectivity(results);
      final wasOffline = _wasOffline;
      _wasOffline = isOffline;
      if (!isOffline && wasOffline == true) _retryPendingOperations();
    });
    try {
      _fidSubscription ??= messaging.onRegistered.listen(
        _onRegistered,
        onError: (dynamic error, StackTrace stackTrace) {
          _handleMessagingError(
            error,
            stackTrace: stackTrace,
            message: 'FID stream update failed',
            operation: 'fid-stream',
          );
        },
      );
    } catch (error, stackTrace) {
      _handleMessagingError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to initialize FCM token listener',
        operation: 'initialize-fid-listener',
      );
    }
  }

  void beginSession() {
    if (_disposed) return;
    _sessionAuthenticated = true;
    _endingSession = false;
    _registrationRetries = 0;
    _fidRetries = 0;
    _retryFid = null;
    _fidRetryGeneration = null;
    _cancelRecoveryTimers();
  }

  void _retryPendingOperations() {
    if (_disposed || _endingSession) return;
    if (_registrationRetryTimer?.isActive ?? false) {
      _registrationRetryTimer!.cancel();
      _registrationRetryTimer = null;
      register();
    }
    final fid = _retryFid;
    if (fid != null && (_fidRetryTimer?.isActive ?? false)) {
      _fidRetryTimer!.cancel();
      _fidRetryTimer = null;
      _retryFidRegistration(fid, _sessionGeneration);
    }
  }

  void _cancelRecoveryTimers() {
    _registrationRetryTimer?.cancel();
    _registrationRetryTimer = null;
    _fidRetryTimer?.cancel();
    _fidRetryTimer = null;
  }

  void _scheduleRegistrationRetry(int generation) {
    if (_registrationRetries >= _maxRecoveryRetries ||
        _disposed ||
        _endingSession ||
        generation != _sessionGeneration) {
      return;
    }
    final retry = ++_registrationRetries;
    _registrationRetryTimer?.cancel();
    _registrationRetryTimer = Timer(_recoveryDelay(retry), () {
      _registrationRetryTimer = null;
      if (generation == _sessionGeneration) register();
    });
  }

  void _scheduleFidRetry(String fid, int generation) {
    if (_fidRetries >= _maxRecoveryRetries ||
        _disposed ||
        _endingSession ||
        generation != _sessionGeneration ||
        _retryFid != fid) {
      return;
    }
    final retry = ++_fidRetries;
    _fidRetryGeneration = generation;
    _fidRetryTimer?.cancel();
    _fidRetryTimer = Timer(_recoveryDelay(retry), () {
      _fidRetryTimer = null;
      _retryFidRegistration(fid, generation);
    });
  }

  void _retryFidRegistration(String fid, int generation) {
    if (_disposed ||
        _endingSession ||
        generation != _sessionGeneration ||
        generation != _fidRetryGeneration ||
        _retryFid != fid ||
        !(_isAuthenticated?.call() ?? false)) {
      return;
    }
    _onRegistered(fid, isRetry: true);
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
        if (_disposed || generation != _sessionGeneration || _endingSession) {
          return;
        }
        _registrationRetries = 0;
        _registrationRetryTimer?.cancel();
        _registrationRetryTimer = null;
      } catch (error, stackTrace) {
        if (_disposed || generation != _sessionGeneration || _endingSession) {
          return;
        }
        if (_isTransientRegistrationError(error)) {
          _scheduleRegistrationRetry(generation);
          return;
        }
        _handleMessagingError(
          error,
          stackTrace: stackTrace,
          message: 'FCM registration failed',
          operation: 'register',
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
    _retryFid = null;
    _cancelRecoveryTimers();
  }

  Future<void> unregister() async {
    try {
      await _pendingFidUpdate?.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      logger.d('FID registration did not finish before logout');
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
        _handleFidError(
          error,
          stackTrace: stackTrace,
          message: 'FID removal failed',
          operation: 'unregister-fid',
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
        _handleMessagingError(
          error,
          stackTrace: stackTrace,
          message: 'FCM unregistration failed',
          operation: 'unregister',
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
    } on TimeoutException {
      logger.d('FCM unregistration timed out');
    }
  }

  void _onRegistered(String fid, {bool isRetry = false}) {
    if (_disposed || _endingSession || !(_isAuthenticated?.call() ?? false)) {
      return;
    }
    if (_latestFid != fid) {
      _latestFid = fid;
      _retryFid = null;
      _fidRetries = 0;
      _fidRetryGeneration = null;
      _fidRetryTimer?.cancel();
      _fidRetryTimer = null;
    }
    if (fid == _registeredFid ||
        fid == _pendingFid ||
        (!isRetry && fid == _retryFid)) {
      return;
    }
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
        if (_disposed) return;
        if (generation != _sessionGeneration || _endingSession) {
          if (_endingSession &&
              generation + 1 == _sessionGeneration &&
              _sessionAuthenticated &&
              _latestFid == fid) {
            _registeredFid = fid;
          }
          return;
        }
        if (_retryFid == fid) _retryFid = null;
        _fidRetries = 0;
        _fidRetryGeneration = null;
        _fidRetryTimer?.cancel();
        _fidRetryTimer = null;
        if (!_disposed &&
            generation == _sessionGeneration &&
            !_endingSession &&
            _latestFid == fid) {
          final previousFid = _registeredFid;
          _registeredFid = fid;
          if (previousFid != null && previousFid != fid) {
            try {
              await authRepository
                  .unregisterFid(previousFid)
                  .timeout(const Duration(seconds: 5));
            } catch (error, stackTrace) {
              _handleFidError(
                error,
                stackTrace: stackTrace,
                message: 'Previous FID removal failed after rotation',
                operation: 'rotate-unregister-fid',
              );
            }
          }
        }
      } catch (error, stackTrace) {
        if (_disposed || generation != _sessionGeneration || _endingSession) {
          return;
        }
        if (_isTransientBackendError(error) && _latestFid == fid) {
          _retryFid = fid;
          _scheduleFidRetry(fid, generation);
          if (_fidRetries >= _maxRecoveryRetries &&
              !(_fidRetryTimer?.isActive ?? false)) {
            _retryFid = null;
            _fidRetryGeneration = null;
          }
        } else {
          _handleFidError(
            error,
            stackTrace: stackTrace,
            message: 'FID registration failed',
            operation: 'register-fid',
          );
        }
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
    _retryFid = null;
    _latestFid = null;
    _cancelRecoveryTimers();
    _registeredFid = null;
    final connectivitySubscription = _connectivitySubscription;
    _connectivitySubscription = null;
    await connectivitySubscription?.cancel();
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
