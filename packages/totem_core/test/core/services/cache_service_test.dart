import 'dart:convert';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:totem_core/core/config/consts.dart';
import 'package:totem_core/core/services/cache_service.dart';
import 'package:totem_core/core/services/secure_storage.dart';

class _MockSecureStorage extends Mock implements SecureStorage {}

void main() {
  late _MockSecureStorage storage;
  late CacheService cache;

  setUp(() {
    storage = _MockSecureStorage();
    cache = CacheService(storage);
    when(() => storage.delete(key: any(named: 'key'))).thenAnswer((_) async {});
  });

  test('reads an unexpired value and applies the default expiration', () async {
    when(() => storage.read(key: 'key')).thenAnswer(
      (_) async => jsonEncode({
        'value': {'answer': 42},
        'timestamp': DateTime.utc(2099).toIso8601String(),
      }),
    );

    check(jsonEncode(await cache.read('key'))).equals('{"answer":42}');
    verifyNever(() => storage.delete(key: 'key'));
  });

  test('deletes and misses an expired value', () async {
    when(() => storage.read(key: 'key')).thenAnswer(
      (_) async => jsonEncode({
        'value': {'answer': 42},
        'timestamp': DateTime.utc(2000).toIso8601String(),
      }),
    );

    check(await cache.read('key')).isNull();
    verify(() => storage.delete(key: 'key')).called(1);
  });

  test('deletes and misses corrupt persisted values', () async {
    when(() => storage.read(key: 'key')).thenAnswer((_) async => '{not-json');

    check(await cache.read('key')).isNull();
    verify(() => storage.delete(key: 'key')).called(1);
  });

  test('clearCache removes every cache namespace', () async {
    when(() => storage.delete(key: any(named: 'key'))).thenAnswer((_) async {});

    await cache.clearCache();

    verifyInOrder([
      () => storage.delete(key: AppConsts.storageSpacesListKey),
      () => storage.delete(key: AppConsts.storageSpacesSummaryKey),
      () => storage.delete(key: AppConsts.storageSubscribedSpacesKey),
      () => storage.delete(key: AppConsts.storageSessionsHistoryKey),
    ]);
    verifyNoMoreInteractions(storage);
  });
}
