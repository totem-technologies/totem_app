import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/core/services/connectivity_service.dart';

void main() {
  group('isOfflineConnectivity', () {
    test('treats an empty result as offline', () {
      expect(isOfflineConnectivity(const []), isTrue);
    });

    test('treats ConnectivityResult.none as offline', () {
      expect(
        isOfflineConnectivity(const [ConnectivityResult.none]),
        isTrue,
      );
    });

    test('treats a connected transport as online', () {
      expect(
        isOfflineConnectivity(const [ConnectivityResult.wifi]),
        isFalse,
      );
    });

    test('treats none mixed with another result as offline', () {
      expect(
        isOfflineConnectivity(const [
          ConnectivityResult.wifi,
          ConnectivityResult.none,
        ]),
        isTrue,
      );
    });
  });
}
