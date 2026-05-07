/// Base class for all custom app exceptions
abstract class AppException implements Exception {
  const AppException(this.message, {this.code, this.details});
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
  const AppNetworkException(super.message, {super.code, super.details});

  factory AppNetworkException.noConnection() {
    return const AppNetworkException(
      'No internet connection available',
      code: 'NO_CONNECTION',
    );
  }

  factory AppNetworkException.timeout() {
    return const AppNetworkException('Request timed out', code: 'TIMEOUT');
  }

  factory AppNetworkException.serverError(int? statusCode, {dynamic details}) {
    return AppNetworkException(
      'Server error occurred',
      code: 'SERVER_ERROR_${statusCode ?? "UNKNOWN"}',
      details: details,
    );
  }
}

/// Authentication-related exceptions
class AppAuthException extends AppException {
  const AppAuthException(super.message, {super.code, super.details});

  factory AppAuthException.unauthenticated() {
    return const AppAuthException(
      'User is not authenticated',
      code: 'UNAUTHENTICATED',
    );
  }

  factory AppAuthException.tokenExpired() {
    return const AppAuthException(
      'Authentication token has expired',
      code: 'TOKEN_EXPIRED',
    );
  }

  factory AppAuthException.invalidCredentials() {
    return const AppAuthException(
      'Invalid credentials provided',
      code: 'INVALID_CREDENTIALS',
    );
  }

  factory AppAuthException.magicLinkExpired() {
    return const AppAuthException(
      'Magic link has expired',
      code: 'MAGIC_LINK_EXPIRED',
    );
  }

  factory AppAuthException.invalidPin() {
    return const AppAuthException('Invalid PIN provided', code: 'INVALID_PIN');
  }

  factory AppAuthException.pinAttemptsExceeded() {
    return const AppAuthException(
      'Maximum PIN attempts exceeded',
      code: 'PIN_ATTEMPTS_EXCEEDED',
    );
  }
  factory AppAuthException.timeout() {
    return const AppAuthException(
      'Timeout during authentication process',
      code: 'AUTH_TIMEOUT',
    );
  }
}

/// Data-related exceptions (parsing, validation, etc.)
class AppDataException extends AppException {
  const AppDataException(super.message, {super.code, super.details});

  factory AppDataException.invalidFormat() {
    return const AppDataException(
      'Data is in an invalid format',
      code: 'INVALID_FORMAT',
    );
  }

  factory AppDataException.missingData() {
    return const AppDataException(
      'Required data is missing',
      code: 'MISSING_DATA',
    );
  }

  factory AppDataException.validationError(String field) {
    return AppDataException(
      'Validation error for field: $field',
      code: 'VALIDATION_ERROR',
      details: {'field': field},
    );
  }
}

/// Feature-specific exceptions
class AppFeatureException extends AppException {
  const AppFeatureException(super.message, {super.code, super.details});

  factory AppFeatureException.notAvailable() {
    return const AppFeatureException(
      'This feature is not available',
      code: 'FEATURE_UNAVAILABLE',
    );
  }

  factory AppFeatureException.permissionDenied() {
    return const AppFeatureException(
      'Permission denied for this feature',
      code: 'PERMISSION_DENIED',
    );
  }
}

/// Video-session specific exceptions
class VideoSessionException extends AppException {
  const VideoSessionException(super.message, {super.code, super.details});

  factory VideoSessionException.connectionFailed() {
    return const VideoSessionException(
      'Failed to connect to video session',
      code: 'VIDEO_CONNECTION_FAILED',
    );
  }

  factory VideoSessionException.mediaPermissionDenied() {
    return const VideoSessionException(
      'Media permission denied',
      code: 'MEDIA_PERMISSION_DENIED',
    );
  }

  factory VideoSessionException.sessionEnded() {
    return const VideoSessionException(
      'Video session has ended',
      code: 'SESSION_ENDED',
    );
  }
}
