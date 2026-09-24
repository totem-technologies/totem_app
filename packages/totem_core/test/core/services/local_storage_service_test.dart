import 'dart:convert';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/config/consts.dart';
import 'package:totem_core/core/services/local_storage_service.dart';
import 'package:totem_core/core/services/secure_storage.dart';

class _MockSecureStorage extends Mock implements SecureStorage {}

void main() {
  late _MockSecureStorage storage;
  late LocalStorageService localStorage;

  setUp(() {
    storage = _MockSecureStorage();
    localStorage = LocalStorageService(storage);
  });

  test('serializes and restores a user through secure storage', () async {
    final user = UserSchema(
      profileAvatarType: ProfileAvatarTypeEnum.td,
      circleCount: 3,
      email: 'keeper@example.com',
      dateCreated: DateTime.utc(2024, 1, 2),
      name: const Omittable('Keeper'),
      slug: const Omittable('keeper'),
    );
    String? persisted;
    when(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((invocation) async {
      persisted = invocation.namedArguments[#value] as String;
    });
    when(
      () => storage.read(key: AppConsts.storageUserProfileKey),
    ).thenAnswer((_) async => persisted);

    await localStorage.saveUser(user);
    final restored = await localStorage.getUser();

    check(jsonEncode(jsonDecode(persisted!))).equals(jsonEncode(user.toJson()));
    check(restored).equals(user);
  });

  test('clears an invalid user payload instead of returning it', () async {
    when(
      () => storage.read(key: AppConsts.storageUserProfileKey),
    ).thenAnswer((_) async => '{invalid');
    when(
      () => storage.delete(key: AppConsts.storageUserProfileKey),
    ).thenAnswer((_) async {});

    check(await localStorage.getUser()).isNull();
    verify(
      () => storage.delete(key: AppConsts.storageUserProfileKey),
    ).called(1);
  });

  test('persists, reads, and clears the onboarding flag', () async {
    when(
      () =>
          storage.write(key: AppConsts.hasSeenWelcomeOnboarding, value: 'true'),
    ).thenAnswer((_) async {});
    when(
      () => storage.read(key: AppConsts.hasSeenWelcomeOnboarding),
    ).thenAnswer((_) async => 'true');
    when(
      () => storage.delete(key: AppConsts.hasSeenWelcomeOnboarding),
    ).thenAnswer((_) async {});

    await localStorage.markWelcomeOnboardingCompleted();
    check(await localStorage.hasSeenWelcomeOnboarding()).equals(true);
    await localStorage.clearWelcomeOnboardingFlag();

    verify(
      () => storage.delete(key: AppConsts.hasSeenWelcomeOnboarding),
    ).called(1);
  });
}
