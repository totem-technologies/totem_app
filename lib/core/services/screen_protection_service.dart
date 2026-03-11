import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:totem_app/core/errors/error_handler.dart';

final screenProtectionProvider = Provider<ScreenProtectionService>((ref) {
  return const ScreenProtectionService();
}, name: 'Screen Protection Provider');

class ScreenProtectionService {
  const ScreenProtectionService();
  static bool _captureProtectionEnabled = false;
  static bool get captureProtectionEnabled => _captureProtectionEnabled;

  static const _totemCaptureDomain = '@totem.org';

  static bool shouldAllowScreenCaptureForEmail(String? email) {
    final normalized = email?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return true;
    }
    return normalized.endsWith(_totemCaptureDomain);
  }

  Future<void> setCaptureProtectionEnabled(bool enabled) async {
    if (_captureProtectionEnabled == enabled) return;
    try {
      if (enabled) {
        await ScreenProtector.preventScreenshotOn();
        await ScreenProtector.protectDataLeakageOn();
      } else {
        await ScreenProtector.preventScreenshotOff();
        await ScreenProtector.protectDataLeakageOff();
      }
      _captureProtectionEnabled = enabled;
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to update screen capture protection',
      );
    }
  }
}
