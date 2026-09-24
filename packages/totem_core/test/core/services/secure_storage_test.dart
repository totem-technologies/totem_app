import 'package:checks/checks.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:totem_core/core/services/secure_storage.dart';

import '../../setup.dart';

class _MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late _MockFlutterSecureStorage plugin;
  late SecureStorage storage;

  setUp(() {
    setupAppConfig();
    plugin = _MockFlutterSecureStorage();
    storage = SecureStorage(plugin);
  });

  test(
    'retries a platform write failure after deleting the stale value',
    () async {
      final failure = PlatformException(code: 'duplicate', message: 'exists');
      var writeAttempts = 0;
      when(() => plugin.write(key: 'token', value: 'secret')).thenAnswer((
        _,
      ) async {
        if (writeAttempts++ == 0) throw failure;
      });
      when(() => plugin.delete(key: 'token')).thenAnswer((_) async {});

      await storage.write(key: 'token', value: 'secret');

      verifyInOrder([
        () => plugin.write(key: 'token', value: 'secret'),
        () => plugin.delete(key: 'token'),
        () => plugin.write(key: 'token', value: 'secret'),
      ]);
    },
  );

  test('swallows unrecoverable write failures', () async {
    when(
      () => plugin.write(key: 'token', value: 'secret'),
    ).thenThrow(StateError('unavailable'));

    await storage.write(key: 'token', value: 'secret');

    verify(() => plugin.write(key: 'token', value: 'secret')).called(1);
  });

  test('returns null when reading fails', () async {
    when(() => plugin.read(key: 'token')).thenThrow(StateError('unavailable'));

    check(await storage.read(key: 'token')).isNull();
  });

  test('swallows delete and deleteAll failures', () async {
    when(
      () => plugin.delete(key: 'token'),
    ).thenThrow(StateError('unavailable'));
    when(() => plugin.deleteAll()).thenThrow(StateError('unavailable'));

    await storage.delete(key: 'token');
    await storage.deleteAll();

    verify(() => plugin.delete(key: 'token')).called(1);
    verify(() => plugin.deleteAll()).called(1);
  });
}
