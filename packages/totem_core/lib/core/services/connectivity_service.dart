import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

export 'package:connectivity_plus/connectivity_plus.dart'
    show ConnectivityResult;

part 'connectivity_service.g.dart';

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
    return connectivityResult.contains(ConnectivityResult.none);
  } catch (_) {
    return false;
  }
}
