import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/api/models/space_detail_schema.dart';
import 'package:totem_app/core/config/consts.dart';
import 'package:totem_app/core/services/secure_storage.dart';

final cacheServiceProvider = Provider<CacheService>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  return CacheService(secureStorage);
});

class CacheService {
  const CacheService(this._secureStorage);

  final SecureStorage _secureStorage;

  Future<void> write({
    required String key,
    required Map<String, dynamic> value,
    DateTime? expirationDate,
  }) async {
    final data = {
      'value': value,
      'expirationDate': expirationDate?.toIso8601String(),
    };
    await _secureStorage.write(key: key, value: jsonEncode(data));
  }

  Future<Map<String, dynamic>?> read(String key) async {
    final dataJson = await _secureStorage.read(key: key);
    if (dataJson != null) {
      final data = jsonDecode(dataJson) as Map<String, dynamic>;
      final expiration = data['expirationDate'] != null
          ? DateTime.parse(data['expirationDate'] as String)
          : null;
      if (expiration == null || DateTime.now().isBefore(expiration)) {
        return data['value'] as Map<String, dynamic>?;
      } else {
        await _secureStorage.delete(key: key);
      }
    }
    return null;
  }

  // Spaces cache methods

  Future<void> saveSpaces(List<SpaceDetailSchema> spaces) {
    return write(
      key: AppConsts.storageSpacesListKey,
      value: {
        'spaces': spaces.map((e) => e.toJson()).toList(),
      },
    );
  }

  Future<List<SpaceDetailSchema>?> getSpaces() async {
    final data = await read(AppConsts.storageSpacesListKey);
    return (data?['spaces'] as List?)
        ?.map<SpaceDetailSchema>(
          (json) => SpaceDetailSchema.fromJson(json as Map<String, dynamic>),
        )
        .toList();
  }

  Future<void> clearSpaces() async {
    await _secureStorage.delete(key: AppConsts.storageSpacesListKey);
  }
}
