import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:totem_app/core/errors/error_handler.dart';

final screenProtectionProvider = Provider<ScreenProtectionService>((ref) {
  return const ScreenProtectionService();
}, name: 'Screen Protection Provider');

const _totemCaptureDomain = '@totem.org';

bool shouldAllowScreenCaptureForEmail(String? email) {
  final normalized = email?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) {
    // Fail-open behavior requested by product while auth data settles.
    return true;
  }
  return normalized.endsWith(_totemCaptureDomain);
}

class ScreenProtectionService {
  const ScreenProtectionService();

  Future<void> setCaptureProtectionEnabled(bool enabled) async {
    try {
      if (enabled) {
        await ScreenProtector.preventScreenshotOn();
        await ScreenProtector.protectDataLeakageOn();
      } else {
        await ScreenProtector.preventScreenshotOff();
        await ScreenProtector.protectDataLeakageOff();
      }
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to update screen capture protection',
      );
    }
  }
}
