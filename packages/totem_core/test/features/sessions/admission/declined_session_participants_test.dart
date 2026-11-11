import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/features/sessions/admission/declined_session_participants.dart';

class _FakePreferences implements SessionAdmissionPreferences {
  final values = <String, String>{};
  final writes = <(String key, String value)>[];
  int failedReads = 0;
  Completer<bool>? nextWrite;
  Completer<void>? writeStarted;

  @override
  String? getString(String key) {
    if (failedReads > 0) {
      failedReads--;
      throw StateError('unavailable');
    }
    return values[key];
  }

  @override
  Future<bool> setString(String key, String value) async {
    writes.add((key, value));
    if (writeStarted case final started? when !started.isCompleted) {
      started.complete();
    }
    final pending = nextWrite;
    nextWrite = null;
    if (pending == null) {
      values[key] = value;
      return true;
    }

    final succeeded = await pending.future;
    if (succeeded) values[key] = value;
    return succeeded;
  }

  @override
  Future<bool> remove(String key) async {
    values.remove(key);
    return true;
  }
}

ProviderContainer _container(
  SessionAdmissionPreferences preferences, {
  Future<void>? preferencesReady,
}) {
  return ProviderContainer(
    overrides: [
      sessionAdmissionPreferencesProvider.overrideWith((ref) async {
        if (preferencesReady != null) await preferencesReady;
        return preferences;
      }),
    ],
  );
}

void main() {
  test(
    'persists immutable declines per session and keeper across reloads',
    () async {
      final preferences = _FakePreferences();
      final first = _container(preferences);
      final provider = declinedSessionParticipantsProvider(
        'session-a',
        'keeper-a',
      );
      final subscription = first.listen(provider, (_, _) {});

      await first.read(provider.future);
      await first.read(provider.notifier).decline('participant-a');
      final declined = first.read(provider).requireValue;
      check(declined).deepEquals({'participant-a'});
      check(() => declined.add('participant-b')).throws<UnsupportedError>();
      subscription.close();
      await first.pump();
      check(first.read(provider.exists)).isFalse();
      first.dispose();

      final reloaded = _container(preferences);
      addTearDown(reloaded.dispose);
      check(await reloaded.read(provider.future)).deepEquals({'participant-a'});
      check(
        await reloaded.read(
          declinedSessionParticipantsProvider('session-b', 'keeper-a').future,
        ),
      ).isEmpty();
      check(
        await reloaded.read(
          declinedSessionParticipantsProvider('session-a', 'keeper-b').future,
        ),
      ).isEmpty();
    },
  );

  test(
    'serializes concurrent updates before publishing the durable result',
    () async {
      final firstWriteGate = Completer<bool>();
      final preferences = _FakePreferences()
        ..nextWrite = firstWriteGate
        ..writeStarted = Completer<void>();
      final container = _container(preferences);
      addTearDown(container.dispose);
      final provider = declinedSessionParticipantsProvider(
        'session-a',
        'keeper-a',
      );

      await container.read(provider.future);
      final first = container.read(provider.notifier).decline('participant-a');
      await preferences.writeStarted!.future;
      final second = container.read(provider.notifier).decline('participant-b');
      check(preferences.writes).length.equals(1);
      check(container.read(provider).requireValue).isEmpty();

      firstWriteGate.complete(true);
      await Future.wait([first, second]);
      check(preferences.writes).length.equals(2);
      check(
        container.read(provider).requireValue,
      ).deepEquals({'participant-a', 'participant-b'});

      final lastWriteGate = Completer<bool>();
      preferences
        ..nextWrite = lastWriteGate
        ..writeStarted = Completer<void>();
      final pending = container
          .read(provider.notifier)
          .decline('participant-c');
      await preferences.writeStarted!.future;
      final clear = container.read(provider.notifier).clear();
      lastWriteGate.complete(true);
      await Future.wait([pending, clear]);
      check(preferences.values).isEmpty();
      check(container.read(provider).requireValue).isEmpty();
    },
  );

  test('waits for initialization before applying an early update', () async {
    final preferencesReady = Completer<void>();
    final preferences = _FakePreferences();
    final container = _container(
      preferences,
      preferencesReady: preferencesReady.future,
    );
    addTearDown(container.dispose);
    final provider = declinedSessionParticipantsProvider(
      'session-a',
      'keeper-a',
    );

    final update = container.read(provider.notifier).decline('participant-a');
    check(preferences.writes).isEmpty();
    preferencesReady.complete();
    await update;

    check(container.read(provider).requireValue).deepEquals({'participant-a'});
  });

  test('surfaces an initialization failure and recovers on retry', () async {
    final preferences = _FakePreferences()..failedReads = 1;
    final container = _container(preferences);
    addTearDown(container.dispose);
    final provider = declinedSessionParticipantsProvider(
      'session-a',
      'keeper-a',
    );

    await check(container.read(provider.future)).throws<StateError>();
    check(container.read(provider).hasError).isTrue();

    container.invalidate(provider);
    check(await container.read(provider.future)).isEmpty();
  });

  test(
    'rejects invalid identities and surfaces durable write failures',
    () async {
      final preferences = _FakePreferences();
      final container = _container(preferences);
      addTearDown(container.dispose);
      final provider = declinedSessionParticipantsProvider(
        'session-a',
        'keeper-a',
      );

      await container.read(provider.future);
      final notifier = container.read(provider.notifier);
      await check(notifier.decline('')).throws<ArgumentError>();
      await check(notifier.allow('keeper-a')).throws<ArgumentError>();

      preferences.nextWrite = Completer<bool>()..complete(false);
      await check(notifier.decline('participant-a')).throws<StateError>();
      check(container.read(provider).requireValue).isEmpty();

      await notifier.decline('participant-a');
      check(
        container.read(provider).requireValue,
      ).deepEquals({'participant-a'});

      await notifier.allow('participant-a');
      check(preferences.values).isEmpty();
      await notifier.decline('participant-a');
      await notifier.clear();
      check(preferences.values).isEmpty();
      check(container.read(provider).requireValue).isEmpty();
    },
  );
}
