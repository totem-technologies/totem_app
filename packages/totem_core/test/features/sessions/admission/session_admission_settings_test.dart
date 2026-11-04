import 'package:checks/checks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/features/sessions/admission/session_admission_settings.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';

import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';

final _testRoomStatusProvider = NotifierProvider<_TestRoomStatus, RoomStatus>(
  _TestRoomStatus.new,
);
final _testSessionScopeProvider =
    NotifierProvider<_TestSessionScope, SessionOptions?>(_TestSessionScope.new);

class _TestRoomStatus extends Notifier<RoomStatus> {
  @override
  RoomStatus build() => RoomStatus.waitingRoom;

  RoomStatus get status => state;

  set status(RoomStatus value) => state = value;
}

class _TestSessionScope extends Notifier<SessionOptions?> {
  @override
  SessionOptions build() => _options('session-a', 'token-a');

  SessionOptions? get scope => state;

  set scope(SessionOptions? value) => state = value;
}

SessionOptions _options(String slug, String token) => SessionOptions(
  sessionSlug: slug,
  token: token,
  cameraEnabled: false,
  microphoneEnabled: false,
  speakerEnabled: true,
  cameraOptions: SessionController.defaultCameraCaptureOptions,
);

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        sessionScopeProvider.overrideWith(
          (ref) => ref.watch(_testSessionScopeProvider),
        ),
        roomStatusProvider.overrideWith(
          (ref) => ref.watch(_testRoomStatusProvider),
        ),
      ],
    );
  });

  tearDown(() => container.dispose());

  test('follows room status until overridden and resets for a new session', () {
    check(container.read(sessionAdmissionSettingsProvider)).isFalse();

    container.read(_testRoomStatusProvider.notifier).status = RoomStatus.active;
    check(container.read(sessionAdmissionSettingsProvider)).isTrue();

    container.read(sessionAdmissionSettingsProvider.notifier).setEnabled(false);
    container.read(_testRoomStatusProvider.notifier).status = RoomStatus.ended;
    check(container.read(sessionAdmissionSettingsProvider)).isFalse();

    container.read(_testSessionScopeProvider.notifier).scope = _options(
      'session-b',
      'token-b',
    );
    check(container.read(sessionAdmissionSettingsProvider)).isTrue();
  });

  for (final enabled in [true, false]) {
    test(
      'explicit $enabled in waiting room survives start and token refresh',
      () {
        container
            .read(sessionAdmissionSettingsProvider.notifier)
            .setEnabled(enabled);
        container.read(_testRoomStatusProvider.notifier).status =
            RoomStatus.active;
        check(container.read(sessionAdmissionSettingsProvider)).equals(enabled);
        container.read(_testSessionScopeProvider.notifier).scope = _options(
          'session-a',
          'new-token',
        );
        check(container.read(sessionAdmissionSettingsProvider)).equals(enabled);
        container.read(_testSessionScopeProvider.notifier).scope = _options(
          'session-b',
          'other-token',
        );
        check(container.read(sessionAdmissionSettingsProvider)).isTrue();
      },
    );
  }

  test('defaults to enabled for unknown room statuses', () {
    container.read(_testRoomStatusProvider.notifier).status =
        RoomStatus.fromJson('paused');

    check(container.read(sessionAdmissionSettingsProvider)).isTrue();
  });
}
