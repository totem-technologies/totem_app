import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/api/models/event_detail_schema.dart';
import 'package:totem_app/api/models/mobile_space_detail_schema.dart';
import 'package:totem_app/api/models/space_schema.dart';
import 'package:totem_app/api/models/summary_spaces_schema.dart';
import 'package:totem_app/core/config/consts.dart';
import 'package:totem_app/core/services/secure_storage.dart';
import 'package:totem_app/shared/logger.dart';

final cacheServiceProvider = Provider<CacheService>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  return CacheService(secureStorage);
});

class CacheService {
  const CacheService(this._secureStorage);

  final SecureStorage _secureStorage;

  Future<void> clearCache() async {
    await _secureStorage.delete(key: AppConsts.storageSpacesListKey);
    await _secureStorage.delete(key: AppConsts.storageSpacesSummaryKey);
    await _secureStorage.delete(key: AppConsts.storageSubscribedSpacesKey);
    await _secureStorage.delete(key: AppConsts.storageSessionsHistoryKey);
  }

  Future<void> write({
    required String key,
    required Map<String, dynamic> value,
    DateTime? expirationDate,
  }) async {
    final data = {
      'value': value,
      'expirationDate': expirationDate?.toIso8601String(),
      'timestamp': DateTime.now().toIso8601String(),
    };
    await _secureStorage.write(key: key, value: jsonEncode(data));
  }

  Future<Map<String, dynamic>?> read(String key) async {
    logger.d('Reading cache for key: $key');
    final dataJson = await _secureStorage.read(key: key);
    if (dataJson != null) {
      final data = jsonDecode(dataJson) as Map<String, dynamic>;
      final timeStamp = data['timestamp'] as String?;
      if (timeStamp == null) {
        await _secureStorage.delete(key: key);
        return null;
      }

      final expiration = data['expirationDate'] != null
          ? DateTime.parse(data['expirationDate'] as String)
          : DateTime.parse(timeStamp).add(const Duration(hours: 24));
      if (DateTime.now().isBefore(expiration)) {
        return data['value'] as Map<String, dynamic>?;
      } else {
        await _secureStorage.delete(key: key);
      }
    }
    return null;
  }

  // Spaces cache methods

  Future<void> saveSpaces(List<MobileSpaceDetailSchema> spaces) {
    return write(
      key: AppConsts.storageSpacesListKey,
      value: {
        'spaces': spaces.map((e) => e.toJson()).toList(),
      },
    );
  }

  Future<List<MobileSpaceDetailSchema>?> getSpaces() async {
    final data = await read(AppConsts.storageSpacesListKey);
    return (data?['spaces'] as List?)
        ?.map<MobileSpaceDetailSchema>(
          (json) =>
              MobileSpaceDetailSchema.fromJson(json as Map<String, dynamic>),
        )
        .toList();
  }

  Future<void> clearSpaces() async {
    await _secureStorage.delete(key: AppConsts.storageSpacesListKey);
  }

  // Spaces Summary

  Future<void> saveSpacesSummary(SummarySpacesSchema summary) {
    return write(
      key: AppConsts.storageSpacesSummaryKey,
      value: summary.toJson(),
    );
  }

  Future<SummarySpacesSchema?> getSpacesSummary() async {
    final data = await read(AppConsts.storageSpacesSummaryKey);
    return data != null ? SummarySpacesSchema.fromJson(data) : null;
  }

  Future<void> clearSpacesSummary() async {
    await _secureStorage.delete(key: AppConsts.storageSpacesSummaryKey);
  }

  // Subscribed Spaces

  Future<void> saveSubscribedSpaces(List<SpaceSchema> spaces) {
    return write(
      key: AppConsts.storageSubscribedSpacesKey,
      value: {
        'spaces': spaces.map((e) => e.toJson()).toList(),
      },
    );
  }

  Future<List<SpaceSchema>?> getSubscribedSpaces() async {
    final data = await read(AppConsts.storageSubscribedSpacesKey);
    return (data?['spaces'] as List?)
        ?.map<SpaceSchema>(
          (json) => SpaceSchema.fromJson(json as Map<String, dynamic>),
        )
        .toList();
  }

  Future<void> clearSubscribedSpaces() async {
    await _secureStorage.delete(key: AppConsts.storageSubscribedSpacesKey);
  }

  // Sessions History

  Future<void> saveSessionsHistory(List<EventDetailSchema> sessions) {
    return write(
      key: AppConsts.storageSessionsHistoryKey,
      value: {'sessions': sessions.map((e) => e.toJson()).toList()},
    );
  }

  Future<List<EventDetailSchema>?> getSessionsHistory() async {
    final data = await read(AppConsts.storageSessionsHistoryKey);
    return (data?['sessions'] as List?)
        ?.map<EventDetailSchema>(
          (json) => EventDetailSchema.fromJson(json as Map<String, dynamic>),
        )
        .toList();
  }

  Future<void> clearSessionsHistory() async {
    await _secureStorage.delete(key: AppConsts.storageSessionsHistoryKey);
  }
}
