import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A wrapper service for flutter_secure_storage to handle secure credential
/// storage
class SecureStorage {
  /// Constructor with optional storage instance for testing
  SecureStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;

  /// Write a value securely
  Future<void> write({required String key, required String value}) async {
    await _storage.write(key: key, value: value);
  }

  /// Read a value securely
  Future<String?> read({required String key}) async {
    return _storage.read(key: key);
  }

  /// Delete a value
  Future<void> delete({required String key}) async {
    await _storage.delete(key: key);
  }

  /// Delete all values
  Future<void> deleteAll() async {
    await _storage.deleteAll();
  }

  /// Check if a key exists
  Future<bool> containsKey({required String key}) async {
    return _storage.containsKey(key: key);
  }
}
