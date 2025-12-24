import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/api/models/user_schema.dart';
import 'package:totem_app/core/config/consts.dart';
import 'package:totem_app/core/services/secure_storage.dart';

final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  final secureStorage = ref.read(secureStorageProvider);
  return LocalStorageService(secureStorage);
}, name: 'Local Storage Service Provider');

class LocalStorageService {
  const LocalStorageService(this._secureStorage);

  final SecureStorage _secureStorage;

  Future<void> saveUser(UserSchema user) async {
    await _secureStorage.write(
      key: AppConsts.storageUserProfileKey,
      value: jsonEncode(user.toJson()),
    );
  }

  Future<UserSchema?> getUser() async {
    final userJson = await _secureStorage.read(
      key: AppConsts.storageUserProfileKey,
    );
    if (userJson != null) {
      try {
        return UserSchema.fromJson(
          jsonDecode(userJson) as Map<String, dynamic>,
        );
      } catch (e) {
        await clearUser();
        return null;
      }
    }
    return null;
  }

  Future<void> clearUser() async {
    await _secureStorage.delete(key: AppConsts.storageUserProfileKey);
  }

  /// Check if the user has seen the welcome onboarding screens
  /// Returns true if they have seen it before, false if it's their first time
  Future<bool> hasSeenWelcomeOnboarding() async {
    final hasSeenString = await _secureStorage.read(
      key: AppConsts.hasSeenWelcomeOnboarding,
    );
    return hasSeenString == 'true';
  }

  /// Mark that the user has completed the welcome onboarding screens
  /// This ensures they won't see the welcome screens again
  Future<void> markWelcomeOnboardingCompleted() async {
    await _secureStorage.write(
      key: AppConsts.hasSeenWelcomeOnboarding,
      value: 'true',
    );
  }

  /// Clear the welcome onboarding flag (useful for testing or reset scenarios)
  Future<void> clearWelcomeOnboardingFlag() async {
    await _secureStorage.delete(key: AppConsts.hasSeenWelcomeOnboarding);
  }
}
