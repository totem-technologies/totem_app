import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' as mui;
import 'package:totem_app/features/auth/controllers/auth_controller.dart';
import 'package:totem_app/features/auth/controllers/user_profile_controller.dart';
import 'package:totem_app/features/profile/screens/profile_details_screen.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/auth/models/auth_state.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/shared/widgets/loading_indicator.dart';

final class _FakeAuthController extends MobileAuthController {
  _FakeAuthController(this.user);

  @override
  final UserSchema user;

  @override
  AuthState build() => AuthState.authenticated(user: user);

  @override
  bool get isAuthenticated => true;

  @override
  Stream<AuthState> get authStateChanges => const Stream.empty();

  @override
  Future<void> checkExistingAuth() async {}

  @override
  Future<void> logout() async {}

  @override
  Future<void> deleteAccount() async {}
}

final class _FakeUserProfileController extends UserProfileController {
  _FakeUserProfileController(this.onUpdate);

  final Future<bool> Function({required String name, required String email})
  onUpdate;

  @override
  FutureOr<void> build() {}

  @override
  Future<bool> updateUserProfile({
    String? name,
    String? email,
    Object? profileImage,
    Object? profileAvatarType,
    String? avatarSeed,
  }) {
    return onUpdate(name: name ?? '', email: email ?? '');
  }
}

void main() {
  final user = UserSchema(
    name: 'Original name',
    profileAvatarType: ProfileAvatarTypeEnum.td,
    circleCount: 0,
    email: 'original@example.com',
    dateCreated: DateTime.utc(2024),
  );

  Future<void> pumpScreen(
    WidgetTester tester, {
    required _FakeUserProfileController profile,
  }) async {
    final auth = _FakeAuthController(user);
    var scheduled = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(() => auth),
          mobileAuthControllerProvider.overrideWithValue(auth),
          userProfileControllerProvider.overrideWith(() => profile),
        ],
        child: mui.MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) {
              if (!scheduled) {
                scheduled = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Navigator.of(context).push(
                    mui.MaterialPageRoute<void>(
                      builder: (_) => const ProfileDetailsScreen(),
                    ),
                  );
                });
              }
              return const Text('profile destination');
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets(
    'profile save exposes loading and prevents duplicate submission',
    (tester) async {
      final update = Completer<bool>();
      var calls = 0;
      final profile = _FakeUserProfileController(({
        required name,
        required email,
      }) {
        calls++;
        return update.future;
      });
      await pumpScreen(tester, profile: profile);

      await tester.enterText(
        find.byType(mui.TextFormField).at(0),
        'Updated name',
      );
      await tester.tap(find.text('Update'));
      await tester.pump();

      check(calls).equals(1);
      check(tester.widgetList(find.byType(LoadingIndicator))).length.equals(1);
      check(
        (tester.widget<mui.ElevatedButton>(
          find.byType(mui.ElevatedButton),
        )).onPressed,
      ).isNull();

      await tester.tap(find.byType(mui.ElevatedButton));
      check(calls).equals(1);

      update.complete(true);
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets('failed profile save recovers and a later save navigates back', (
    tester,
  ) async {
    var calls = 0;
    final profile = _FakeUserProfileController(({
      required name,
      required email,
    }) {
      calls++;
      return Future.value(calls > 1);
    });
    await pumpScreen(tester, profile: profile);

    await tester.enterText(find.byType(mui.TextFormField).at(0), 'Retry name');
    await tester.tap(find.text('Update'));
    await tester.pump();
    await tester.pump();

    check(calls).equals(1);
    check(
      tester.widgetList(find.byType(ProfileDetailsScreen)),
    ).length.equals(1);
    check(
      tester
          .widget<mui.ElevatedButton>(find.byType(mui.ElevatedButton))
          .onPressed,
    ).isNotNull();

    await tester.tap(find.text('Update'));
    await tester.pump();
    await tester.pump();

    check(calls).equals(2);
    check(
      tester.widgetList(find.byType(ProfileDetailsScreen)),
    ).length.equals(0);
    await tester.pumpAndSettle();
  });
}
