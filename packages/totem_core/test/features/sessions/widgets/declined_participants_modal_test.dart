import 'package:checks/checks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/repositories/user_repository.dart';
import 'package:totem_core/features/sessions/admission/declined_session_participants.dart';
import 'package:totem_core/features/sessions/widgets/declined_participants_modal.dart';

import '../../../setup.dart';

class _FakePreferences implements SessionAdmissionPreferences {
  final values = <String, String>{};
  bool writesSucceed = true;

  @override
  String? getString(String key) => values[key];

  @override
  Future<bool> setString(String key, String value) async {
    if (!writesSucceed) return false;
    values[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    if (!writesSucceed) return false;
    values.remove(key);
    return true;
  }
}

void main() {
  setUpAll(setupAppConfig);

  testWidgets('allows a declined participant without joining them', (
    tester,
  ) async {
    final preferences = _FakePreferences();
    final container = ProviderContainer(
      overrides: [
        sessionAdmissionPreferencesProvider.overrideWith(
          (ref) async => preferences,
        ),
        userProfileProvider.overrideWith(
          (ref, slug) => Future.value(
            PublicUserSchema(
              slug: Omittable(slug),
              name: Omittable('User $slug'),
              profileAvatarType: ProfileAvatarTypeEnum.td,
              circleCount: const Omittable(0),
              dateCreated: DateTime(2024),
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final provider = declinedSessionParticipantsProvider(
      'test-session',
      'keeper-1',
    );
    await container.read(provider.future);
    await container.read(provider.notifier).decline('user-1');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: DeclinedParticipants(
              sessionSlug: 'test-session',
              keeperIdentity: 'keeper-1',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    check(tester.widgetList(find.text('User user-1'))).length.equals(1);
    await tester.tap(find.text('Allow'));
    await tester.pumpAndSettle();

    check(container.read(provider).requireValue).isEmpty();
    check(tester.widgetList(find.text('User user-1'))).isEmpty();
    check(
      tester.widgetList(find.text('No participants have been declined')),
    ).length.equals(1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('keeps a participant visible and allows retry after failure', (
    tester,
  ) async {
    final preferences = _FakePreferences();
    final container = ProviderContainer(
      overrides: [
        sessionAdmissionPreferencesProvider.overrideWith(
          (ref) async => preferences,
        ),
        userProfileProvider.overrideWith(
          (ref, slug) => Future.value(
            PublicUserSchema(
              slug: Omittable(slug),
              name: Omittable('User $slug'),
              profileAvatarType: ProfileAvatarTypeEnum.td,
              circleCount: const Omittable(0),
              dateCreated: DateTime(2024),
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final provider = declinedSessionParticipantsProvider(
      'test-session',
      'keeper-1',
    );
    await container.read(provider.future);
    await container.read(provider.notifier).decline('user-1');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: DeclinedParticipants(
              sessionSlug: 'test-session',
              keeperIdentity: 'keeper-1',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    preferences.writesSucceed = false;
    await tester.tap(find.text('Allow'));
    await tester.pumpAndSettle();

    check(tester.widgetList(find.text('User user-1'))).length.equals(1);
    final pendingAllowButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Allow'),
    );
    check(pendingAllowButton.onPressed).isNull();

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    final retryAllowButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Allow'),
    );
    check(retryAllowButton.onPressed).isNotNull();
    preferences.writesSucceed = true;
    await tester.tap(find.text('Allow'));
    await tester.pumpAndSettle();

    check(container.read(provider).requireValue).isEmpty();
    check(tester.widgetList(find.text('User user-1'))).isEmpty();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
