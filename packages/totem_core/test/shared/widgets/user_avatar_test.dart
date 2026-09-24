import 'package:checks/checks.dart';
import 'package:flutter_boring_avatars/flutter_boring_avatars.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/auth/models/auth_state.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/repositories/user_repository.dart';
import 'package:totem_core/shared/widgets/user_avatar.dart';

import '../../auth/controllers/auth_controller_mock.dart';

const _profileImage = 'avatars/retained-image.jpg';

UserSchema _currentUser({String? profileAvatarSeed}) => UserSchema(
  profileAvatarType: ProfileAvatarTypeEnum.td,
  circleCount: 0,
  email: 'user@test.com',
  dateCreated: DateTime(2024),
  profileAvatarSeed: profileAvatarSeed,
  profileImage: const Omittable(_profileImage),
);

PublicUserSchema _profile() => PublicUserSchema(
  profileAvatarType: ProfileAvatarTypeEnum.td,
  dateCreated: DateTime(2024),
  profileImage: const Omittable(_profileImage),
);

void main() {
  testWidgets(
    'current user uses a generated avatar when a retained image is not selected',
    (tester) async {
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(
              () => FakeAuthController(
                AuthState.authenticated(user: _currentUser()),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: UserAvatar.currentUser()),
          ),
        ),
      );
      await tester.pump();

      check(
        tester.widgetList(find.byType(AnimatedBoringAvatar)),
      ).length.equals(1);
    },
  );

  testWidgets('null user schema does not use the current user avatar', (
    tester,
  ) async {
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => FakeAuthController(
              AuthState.authenticated(
                user: _currentUser(profileAvatarSeed: 'viewer-seed'),
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: UserAvatar.fromUserSchema(null)),
        ),
      ),
    );
    await tester.pump();

    final avatar = tester.widget<AnimatedBoringAvatar>(
      find.byType(AnimatedBoringAvatar),
    );
    check(avatar.name).equals('default');
  });

  testWidgets(
    'slug profile uses a generated avatar when a retained image is not selected',
    (tester) async {
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(
              () => FakeAuthController(AuthState.unauthenticated()),
            ),
            userProfileProvider.overrideWith((ref, slug) async => _profile()),
          ],
          child: const MaterialApp(
            home: Scaffold(body: UserAvatar.slug('user')),
          ),
        ),
      );
      await tester.pump();

      check(
        tester.widgetList(find.byType(AnimatedBoringAvatar)),
      ).length.equals(1);
    },
  );
}
