/// Base class for all custom app exceptions
///
/// Exception instances must remain non-const because error reporting
/// deduplicates by identity. Canonicalized const exceptions would cause
/// separate failures to be mistaken for the same occurrence.
abstract class AppException implements Exception {
  new(this.message, {this.code, this.details});
  final String message;
  final String? code;
  final dynamic details;

  @override
  String toString() {
    return '$runtimeType: $message${code != null ? ' (code: $code)' : ''};\n$details';
  }
}

/// Network-related exceptions (connectivity, timeouts, etc.)
class AppNetworkException extends AppException {
  new(super.message, {super.code, super.details});

  factory noConnection() {
    return AppNetworkException(
      'No internet connection available',
      code: 'NO_CONNECTION',
    );
  }

  factory timeout() {
    return AppNetworkException('Request timed out', code: 'TIMEOUT');
  }

  factory serverError(int? statusCode, {dynamic details}) {
    return AppNetworkException(
      'Server error occurred',
      code: 'SERVER_ERROR_${statusCode ?? "UNKNOWN"}',
      details: details,
    );
  }
}

/// Authentication-related exceptions
class AppAuthException extends AppException {
  new(super.message, {super.code, super.details});

  factory unauthenticated() {
    return AppAuthException(
      'User is not authenticated',
      code: 'UNAUTHENTICATED',
    );
  }

  factory tokenExpired() {
    return AppAuthException(
      'Authentication token has expired',
      code: 'TOKEN_EXPIRED',
    );
  }

  factory invalidCredentials() {
    return AppAuthException(
      'Invalid credentials provided',
      code: 'INVALID_CREDENTIALS',
    );
  }

  factory magicLinkExpired() {
    return AppAuthException(
      'Magic link has expired',
      code: 'MAGIC_LINK_EXPIRED',
    );
  }

  factory invalidPin() {
    return AppAuthException('Invalid PIN provided', code: 'INVALID_PIN');
  }

  factory pinAttemptsExceeded() {
    return AppAuthException(
      'Maximum PIN attempts exceeded',
      code: 'PIN_ATTEMPTS_EXCEEDED',
    );
  }
  factory timeout() {
    return AppAuthException(
      'Timeout during authentication process',
      code: 'AUTH_TIMEOUT',
    );
  }
}

/// Data-related exceptions (parsing, validation, etc.)
class AppDataException extends AppException {
  new(super.message, {super.code, super.details});

  factory invalidFormat() {
    return AppDataException(
      'Data is in an invalid format',
      code: 'INVALID_FORMAT',
    );
  }

  factory missingData() {
    return AppDataException('Required data is missing', code: 'MISSING_DATA');
  }

  factory validationError(String field) {
    return AppDataException(
      'Validation error for field: $field',
      code: 'VALIDATION_ERROR',
      details: {'field': field},
    );
  }
}

/// Feature-specific exceptions
class AppFeatureException extends AppException {
  new(super.message, {super.code, super.details});

  factory notAvailable() {
    return AppFeatureException(
      'This feature is not available',
      code: 'FEATURE_UNAVAILABLE',
    );
  }

  factory permissionDenied() {
    return AppFeatureException(
      'Permission denied for this feature',
      code: 'PERMISSION_DENIED',
    );
  }
}

/// Video-session specific exceptions
class VideoSessionException extends AppException {
  new(super.message, {super.code, super.details});

  factory connectionFailed() {
    return VideoSessionException(
      'Failed to connect to video session',
      code: 'VIDEO_CONNECTION_FAILED',
    );
  }

  factory mediaPermissionDenied() {
    return VideoSessionException(
      'Media permission denied',
      code: 'MEDIA_PERMISSION_DENIED',
    );
  }

  factory sessionEnded() {
    return VideoSessionException(
      'Video session has ended',
      code: 'SESSION_ENDED',
    );
  }
}
