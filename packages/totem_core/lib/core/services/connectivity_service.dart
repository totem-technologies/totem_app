import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_core/shared/logger.dart';

export 'package:connectivity_plus/connectivity_plus.dart'
    show ConnectivityResult;

part 'connectivity_service.g.dart';

const _initialOfflineConfirmationDelay = Duration(milliseconds: 500);

bool isOfflineConnectivity(List<ConnectivityResult> results) {
  return results.isEmpty || results.contains(ConnectivityResult.none);
}

Future<bool?> _readOfflineStatus(Connectivity connectivity) async {
  try {
    return isOfflineConnectivity(await connectivity.checkConnectivity());
  } catch (error, stackTrace) {
    logger.d(
      'Failed to get the current connectivity status',
      error: error,
      stackTrace: stackTrace,
    );
    return null;
  }
}

Future<bool> checkIsOffline(Connectivity connectivity) async {
  return await _readOfflineStatus(connectivity) ?? false;
}

@riverpod
Connectivity connectivity(Ref ref) {
  return Connectivity();
}

@Riverpod(keepAlive: true)
Stream<bool> isOffline(Ref ref) {
  final connectivity = ref.watch(connectivityProvider);
  final controller = StreamController<bool>();
  Timer? initialOfflineConfirmationTimer;
  Object? activeCheck;
  bool? lastValue;
  var disposed = false;

  void emit(bool value) {
    if (disposed || value == lastValue) return;
    lastValue = value;
    controller.add(value);
  }

  Future<void> confirmInitialOffline() async {
    initialOfflineConfirmationTimer = null;
    final isOffline = await _readOfflineStatus(connectivity);
    if (disposed || lastValue != null) return;
    emit(isOffline ?? true);
  }

  void emitStatus(bool value) {
    if (lastValue != null || !value) {
      initialOfflineConfirmationTimer?.cancel();
      initialOfflineConfirmationTimer = null;
      emit(value);
      return;
    }

    initialOfflineConfirmationTimer ??= Timer(
      _initialOfflineConfirmationDelay,
      () => unawaited(confirmInitialOffline()),
    );
  }

  Future<void> refresh() async {
    final check = Object();
    activeCheck = check;

    final isOffline = await _readOfflineStatus(connectivity);
    if (!identical(activeCheck, check)) return;
    if (isOffline != null) {
      emitStatus(isOffline);
    } else if (lastValue == null) {
      emit(false);
    }
  }

  final subscription = connectivity.onConnectivityChanged.listen(
    (result) {
      activeCheck = null;
      emitStatus(isOfflineConnectivity(result));
    },
    onError: (Object error, StackTrace stackTrace) {
      if (disposed) return;
      logger.d(
        'Failed to observe connectivity changes',
        error: error,
        stackTrace: stackTrace,
      );
      controller.addError(error, stackTrace);
    },
  );
  final lifecycleListener = AppLifecycleListener(
    onResume: () => unawaited(refresh()),
  );

  ref.onDispose(() {
    disposed = true;
    initialOfflineConfirmationTimer?.cancel();
    lifecycleListener.dispose();
    unawaited(subscription.cancel());
    unawaited(controller.close());
  });

  unawaited(refresh());
  return controller.stream;
}
