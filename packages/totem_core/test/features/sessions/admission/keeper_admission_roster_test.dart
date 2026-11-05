import 'dart:async';
import 'dart:convert';

import 'package:checks/checks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/features/sessions/admission/declined_session_participants.dart';
import 'package:totem_core/features/sessions/admission/keeper_admission_roster.dart';

class _FakePreferences implements SessionAdmissionPreferences {
  final values = <String, String>{};
  final writes = <(String key, String value)>[];
  final removals = <String>[];
  Completer<bool>? nextWrite;
  Completer<void>? writeStarted;
  int failedReads = 0;

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
    final started = writeStarted;
    if (started != null && !started.isCompleted) started.complete();
    final result = nextWrite;
    nextWrite = null;
    if (result == null) {
      values[key] = value;
      return true;
    }
    final persisted = await result.future;
    if (persisted) values[key] = value;
    return persisted;
  }

  @override
  Future<bool> remove(String key) async {
    removals.add(key);
    values.remove(key);
    return true;
  }
}

ProviderContainer _container(SessionAdmissionPreferences preferences) {
  return ProviderContainer(
    overrides: [
      sessionAdmissionPreferencesProvider.overrideWith((ref) async {
        return preferences;
      }),
    ],
  );
}

String _key(String sessionSlug, String keeperIdentity) =>
    'session_admission_keeper_roster:${Uri.encodeComponent(sessionSlug)}:'
    '${Uri.encodeComponent(keeperIdentity)}';

Map<String, Object?> _payload({
  String generation = 'generation-a',
  int revision = 0,
  List<String> members = const [],
  List<String> awaitingReadiness = const [],
}) => {
  'version': 1,
  'generation': generation,
  'revision': revision,
  'members': members,
  'awaitingReadiness': awaitingReadiness,
};

void main() {
  test(
    'persists roster state per session and keeper across containers',
    () async {
      final preferences = _FakePreferences();
      final provider = keeperAdmissionRosterProvider('session-a', 'keeper-a');
      final first = _container(preferences);
      final subscription = first.listen(provider, (_, _) {});

      final store = await first.read(provider.future);
      store.replace(
        ['muted-participant', 'pending-participant'],
        4,
        awaitingReadiness: ['pending-participant'],
      );
      await first.read(provider.notifier).persist();
      subscription.close();
      await first.pump();
      check(first.exists(provider)).isFalse();
      first.dispose();

      final reloaded = _container(preferences);
      addTearDown(reloaded.dispose);
      final restored = await reloaded.read(provider.future);
      check(restored.keeperGeneration).equals(store.keeperGeneration);
      check(restored.revision).equals(4);
      check(restored.members.toSet()).deepEquals({
        'muted-participant',
        'pending-participant',
      });
      check(
        restored.awaitingReadiness.toSet(),
      ).deepEquals({'pending-participant'});

      final otherScope = await reloaded.read(
        keeperAdmissionRosterProvider('session-b', 'keeper-a').future,
      );
      check(otherScope.members).isEmpty();
      check(
        (await reloaded.read(
          keeperAdmissionRosterProvider('session-a', 'keeper-b').future,
        )).members,
      ).isEmpty();
    },
  );

  test(
    'surfaces read and schema failures',
    () async {
      final provider = keeperAdmissionRosterProvider('session-a', 'keeper-a');
      final readFailure = _container(_FakePreferences()..failedReads = 1);
      addTearDown(readFailure.dispose);

      await check(readFailure.read(provider.future)).throws<StateError>();
      check(readFailure.read(provider).hasError).isTrue();

      final malformedPreferences = _FakePreferences()
        ..values[_key('session-a', 'keeper-a')] = jsonEncode(
          _payload(members: ['x'], awaitingReadiness: ['not-a-member']),
        );
      final malformed = _container(malformedPreferences);
      addTearDown(malformed.dispose);
      await check(malformed.read(provider.future)).throws<StateError>();
      check(malformed.read(provider).hasError).isTrue();
    },
  );

  test('rejects invalid persisted roster data', () async {
    final provider = keeperAdmissionRosterProvider('session-a', 'keeper-a');

    for (final payload in [
      _payload(generation: ''),
      _payload(revision: -1),
      _payload(members: ['keeper-a']),
      _payload(members: ['x' * 257]),
      {
        'version': 2,
        'generation': 'generation-a',
        'revision': 0,
        'members': <String>[],
        'awaitingReadiness': <String>[],
      },
    ]) {
      final preferences = _FakePreferences()
        ..values[_key('session-a', 'keeper-a')] = jsonEncode(payload);
      final container = _container(preferences);
      addTearDown(container.dispose);
      await check(container.read(provider.future)).throws<StateError>();
    }
  });

  test(
    'removes ended roster after queued writes without resurrecting it',
    () async {
      final firstWrite = Completer<bool>();
      final preferences = _FakePreferences()
        ..nextWrite = firstWrite
        ..writeStarted = Completer<void>();
      final container = _container(preferences);
      addTearDown(container.dispose);
      final provider = keeperAdmissionRosterProvider('session-a', 'keeper-a');
      final store = await container.read(provider.future);
      final notifier = container.read(provider.notifier);

      store.replace(['first'], 1);
      final first = notifier.persist();
      await preferences.writeStarted!.future;
      store.replace(['second'], 2, awaitingReadiness: ['second']);
      final second = notifier.persist();
      final clear = notifier.clear();
      check(store.members).isEmpty();
      check(store.revision).equals(0);
      check(preferences.writes).length.equals(1);

      firstWrite.complete(true);
      await Future.wait([first, second, clear]);

      check(preferences.values).isEmpty();
      check(preferences.removals).deepEquals([_key('session-a', 'keeper-a')]);
      check(
        preferences.writes
            .map((write) => (jsonDecode(write.$2) as Map)['revision'])
            .toList(),
      ).deepEquals([1, 2]);
    },
  );

  test('keeps the loaded store authoritative after a failed write', () async {
    final preferences = _FakePreferences();
    final container = _container(preferences);
    addTearDown(container.dispose);
    final provider = keeperAdmissionRosterProvider('session-a', 'keeper-a');
    final store = await container.read(provider.future);
    final notifier = container.read(provider.notifier);
    store.replace(['participant'], 3);
    preferences.nextWrite = Completer<bool>()..complete(false);

    await check(notifier.persist()).throws<StateError>();
    check(store.members.toSet()).deepEquals({'participant'});
    check(store.revision).equals(3);

    await notifier.persist();
    final reloaded = _container(preferences);
    addTearDown(reloaded.dispose);
    check(
      (await reloaded.read(provider.future)).members.toSet(),
    ).deepEquals({'participant'});
  });
}
