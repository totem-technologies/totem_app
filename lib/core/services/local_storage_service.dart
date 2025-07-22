import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/api/models/user_schema.dart';
import 'package:totem_app/core/config/consts.dart';
import 'package:totem_app/core/services/secure_storage.dart';

final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  return LocalStorageService(secureStorage);
});

class LocalStorageService {
  const LocalStorageService(this._secureStorage);

  final SecureStorage _secureStorage;

  Future<void> saveUser(UserSchema user) async {
    await _secureStorage.write(
      key: AppConsts.userProfile,
      value: jsonEncode(user.toJson()),
    );
  }

  Future<UserSchema?> getUser() async {
    final userJson = await _secureStorage.read(key: AppConsts.userProfile);
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
    await _secureStorage.delete(key: AppConsts.userProfile);
  }
}
