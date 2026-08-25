import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_core/shared/logger.dart';

export 'package:connectivity_plus/connectivity_plus.dart'
    show ConnectivityResult;

part 'connectivity_service.g.dart';

bool isOfflineConnectivity(List<ConnectivityResult> results) {
  return results.isEmpty || results.contains(ConnectivityResult.none);
}

@riverpod
Connectivity connectivity(Ref ref) {
  return Connectivity();
}

@riverpod
Stream<List<ConnectivityResult>> connectivityStream(Ref ref) {
  return ref.read(connectivityProvider).onConnectivityChanged;
}

@riverpod
Future<bool> isOffline(Ref ref) async {
  try {
    final connectivityResult = await ref
        .read(connectivityProvider)
        .checkConnectivity();
    return isOfflineConnectivity(connectivityResult);
  } catch (error, stackTrace) {
    logger.d(
      'Failed to get the current connectivity status',
      error: error,
      stackTrace: stackTrace,
    );
    return false;
  }
}
