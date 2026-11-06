import 'dart:async';
import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'declined_session_participants.g.dart';

class CorruptSessionAdmissionData extends StateError {
  CorruptSessionAdmissionData() : super('Invalid saved session admission data');
}

abstract interface class SessionAdmissionPreferences {
  String? getString(String key);

  Future<bool> setString(String key, String value);

  Future<bool> remove(String key);
}

final class SharedPreferencesSessionAdmissionPreferences
    implements SessionAdmissionPreferences {
  SharedPreferencesSessionAdmissionPreferences(this._preferences);

  final SharedPreferences _preferences;

  @override
  String? getString(String key) => _preferences.getString(key);

  @override
  Future<bool> setString(String key, String value) =>
      _preferences.setString(key, value);

  @override
  Future<bool> remove(String key) => _preferences.remove(key);
}

@Riverpod(keepAlive: true)
Future<SessionAdmissionPreferences> sessionAdmissionPreferences(Ref ref) async {
  return SharedPreferencesSessionAdmissionPreferences(
    await SharedPreferences.getInstance(),
  );
}

@riverpod
class DeclinedSessionParticipants extends _$DeclinedSessionParticipants {
  static const _storagePrefix = 'session_admission_declined_participants';

  Future<void> _operations = Future.value();
  Future<Set<String>>? _initialization;
  var _initializationGeneration = 0;
  late String _sessionSlug;
  late String _keeperIdentity;
  late SessionAdmissionPreferences _preferences;
  Set<String> _declined = const <String>{};

  @override
  Future<Set<String>> build(String sessionSlug, String keeperIdentity) {
    _validateSession(sessionSlug, keeperIdentity);
    _sessionSlug = sessionSlug;
    _keeperIdentity = keeperIdentity;
    final generation = ++_initializationGeneration;
    return _initialization = _initialize(
      sessionSlug,
      keeperIdentity,
      generation,
    );
  }

  Future<Set<String>> _initialize(
    String sessionSlug,
    String keeperIdentity,
    int generation,
  ) async {
    final preferences = await ref.watch(
      sessionAdmissionPreferencesProvider.future,
    );
    final declined = Set.unmodifiable(
      _readDeclined(
        preferences,
        _storageKeyFor(sessionSlug, keeperIdentity),
        keeperIdentity,
      ),
    );
    if (generation == _initializationGeneration) {
      _sessionSlug = sessionSlug;
      _keeperIdentity = keeperIdentity;
      _preferences = preferences;
      _declined = declined;
    }
    return declined;
  }

  Future<void> decline(String identity) async {
    await _update(identity, add: true);
  }

  Future<void> allow(String identity) async {
    await _update(identity, add: false);
  }

  Future<void> clear() {
    final link = ref.keepAlive();
    final operation = _operations.then((_) async {
      await _awaitInitialization();
      if (!await _preferences.remove(_storageKey)) {
        throw StateError('Could not clear declined session participants');
      }
      _declined = const <String>{};
      if (ref.mounted) state = AsyncData(_declined);
    });
    _operations = operation.catchError((Object _) {});
    return operation.whenComplete(link.close);
  }

  Future<void> resetCorruptData() {
    if (state.error is! CorruptSessionAdmissionData) {
      throw StateError('Declined participants data is not corrupt');
    }
    final key = _storageKey;
    final link = ref.keepAlive();
    final operation = _operations.then((_) async {
      final preferences = await ref.read(
        sessionAdmissionPreferencesProvider.future,
      );
      if (!await preferences.remove(key)) {
        throw StateError('Could not clear declined session participants');
      }
      if (ref.mounted) ref.invalidateSelf();
    });
    _operations = operation.catchError((Object _) {});
    return operation.whenComplete(link.close);
  }

  Future<void> _update(String identity, {required bool add}) {
    final link = ref.keepAlive();
    final operation = _operations.then((_) async {
      await _awaitInitialization();
      _validateIdentity(identity);
      final updated = {..._declined};
      final changed = add ? updated.add(identity) : updated.remove(identity);
      if (!changed) return;

      final persisted = updated.isEmpty
          ? await _preferences.remove(_storageKey)
          : await _preferences.setString(
              _storageKey,
              jsonEncode(updated.toList()..sort()),
            );
      if (!persisted) {
        throw StateError('Could not persist declined session participants');
      }

      _declined = Set.unmodifiable(updated);
      if (ref.mounted) state = AsyncData(_declined);
    });
    _operations = operation.catchError((Object _) {});
    return operation.whenComplete(link.close);
  }

  Future<void> _awaitInitialization() async {
    final initialization = _initialization;
    if (initialization == null) {
      throw StateError('Declined participants are not initialized');
    }
    await initialization;
  }

  Set<String> _readDeclined(
    SessionAdmissionPreferences preferences,
    String storageKey,
    String keeperIdentity,
  ) {
    final encoded = preferences.getString(storageKey);
    if (encoded == null) return const <String>{};
    final Object? decoded;
    try {
      decoded = jsonDecode(encoded);
    } on FormatException {
      throw CorruptSessionAdmissionData();
    }
    if (decoded is! List ||
        decoded.any(
          (value) =>
              value is! String ||
              value.trim().isEmpty ||
              value == keeperIdentity,
        )) {
      throw CorruptSessionAdmissionData();
    }
    return decoded.cast<String>().toSet();
  }

  String get _storageKey => _storageKeyFor(_sessionSlug, _keeperIdentity);

  String _storageKeyFor(String sessionSlug, String keeperIdentity) =>
      '$_storagePrefix:${Uri.encodeComponent(sessionSlug)}:'
      '${Uri.encodeComponent(keeperIdentity)}';

  void _validateSession(String sessionSlug, String keeperIdentity) {
    if (sessionSlug.trim().isEmpty || keeperIdentity.trim().isEmpty) {
      throw ArgumentError('Session slug and keeper identity must not be blank');
    }
  }

  void _validateIdentity(String identity) {
    if (identity.trim().isEmpty || identity == _keeperIdentity) {
      throw ArgumentError(
        'Participant identity must not be blank or the keeper',
      );
    }
  }
}
