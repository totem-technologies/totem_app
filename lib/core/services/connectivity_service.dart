import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'connectivity_service.g.dart';

@riverpod
Connectivity connectivity(Ref ref) {
  return Connectivity();
}

@riverpod
Stream<List<ConnectivityResult>> connectivityStream(Ref ref) {
  return ref.watch(connectivityProvider).onConnectivityChanged;
}

@riverpod
Future<bool> isOffline(Ref ref) async {
  final connectivityResult = await ref
      .watch(connectivityProvider)
      .checkConnectivity();
  return connectivityResult.contains(ConnectivityResult.none);
}
