import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/config/consts.dart';
import 'package:totem_core/core/services/secure_storage.dart';
import 'package:totem_core/shared/logger.dart';

final cacheServiceProvider = Provider<CacheService>((ref) {
  final secureStorage = ref.read(secureStorageProvider);
  return CacheService(secureStorage);
}, name: 'Cache Service Provider');

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
    if (dataJson == null) return null;

    try {
      final data = jsonDecode(dataJson);
      if (data is Map<String, dynamic>) {
        final timeStamp = data['timestamp'];
        final expirationValue = data['expirationDate'];
        if (timeStamp is String &&
            (expirationValue == null || expirationValue is String)) {
          final expiration = expirationValue is String
              ? DateTime.parse(expirationValue)
              : DateTime.parse(timeStamp).add(const Duration(hours: 24));
          if (DateTime.now().isBefore(expiration)) {
            final value = data['value'];
            if (value == null || value is Map<String, dynamic>) {
              return value as Map<String, dynamic>?;
            }
          }
        }
      }
    } on FormatException {
      // Treat malformed persisted data as a cache miss.
    }

    await _secureStorage.delete(key: key);
    return null;
  }

  // Spaces cache methods

  Future<void> saveSpaces(List<MobileSpaceDetailSchema> spaces) {
    return write(
      key: AppConsts.storageSpacesListKey,
      value: {'spaces': spaces.map((e) => e.toJson()).toList()},
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
      value: {'spaces': spaces.map((e) => e.toJson()).toList()},
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

  Future<void> saveSessionsHistory(List<SessionDetailSchema> sessions) {
    return write(
      key: AppConsts.storageSessionsHistoryKey,
      value: {'sessions': sessions.map((e) => e.toJson()).toList()},
    );
  }

  Future<List<SessionDetailSchema>?> getSessionsHistory() async {
    final data = await read(AppConsts.storageSessionsHistoryKey);
    return (data?['sessions'] as List?)
        ?.map<SessionDetailSchema>(
          (json) => SessionDetailSchema.fromJson(json as Map<String, dynamic>),
        )
        .toList();
  }

  Future<void> clearSessionsHistory() async {
    await _secureStorage.delete(key: AppConsts.storageSessionsHistoryKey);
  }
}
