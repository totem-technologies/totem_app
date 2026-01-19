import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:totem_app/core/errors/error_handler.dart';

final secureStorageProvider = Provider<SecureStorage>((ref) {
  return SecureStorage();
}, name: 'Secure Storage Provider');

/// A wrapper service for flutter_secure_storage to handle secure credential
/// storage
class SecureStorage {
  /// Constructor with optional storage instance for testing
  SecureStorage([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
          );
  final FlutterSecureStorage _storage;

  /// Write a value securely
  Future<void> write({required String key, required String value}) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Error writing secure storage key: $key',
      );
    }
  }

  /// Read a value securely
  Future<String?> read({required String key}) async {
    try {
      return _storage.read(key: key);
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Error reading secure storage key: $key',
      );
      return null;
    }
  }

  /// Delete a value
  Future<void> delete({required String key}) async {
    try {
      await _storage.delete(key: key);
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Error deleting secure storage key: $key',
      );
    }
  }

  /// Delete all values
  Future<void> deleteAll() async {
    try {
      await _storage.deleteAll();
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Error deleting all secure storage keys',
      );
    }
  }

  /// Check if a key exists
  Future<bool> containsKey({required String key}) async {
    return _storage.containsKey(key: key);
  }
}
