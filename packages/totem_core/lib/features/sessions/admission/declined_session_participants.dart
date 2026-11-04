import 'dart:async';
import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'declined_session_participants.g.dart';

abstract interface class SessionAdmissionPreferences {
  String? getString(String key);

  Future<bool> setString(String key, String value);
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
}

@Riverpod(keepAlive: true)
Future<SessionAdmissionPreferences> sessionAdmissionPreferences(Ref ref) async {
  return SharedPreferencesSessionAdmissionPreferences(
    await SharedPreferences.getInstance(),
  );
}

@Riverpod(keepAlive: true)
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
      _readDeclined(preferences, _storageKeyFor(sessionSlug, keeperIdentity)),
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

  Future<void> _update(String identity, {required bool add}) {
    final operation = _operations.then((_) async {
      await _awaitInitialization();
      _validateIdentity(identity);
      final updated = {..._declined};
      final changed = add ? updated.add(identity) : updated.remove(identity);
      if (!changed) return;

      final persisted = await _preferences.setString(
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
    return operation;
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
  ) {
    final encoded = preferences.getString(storageKey);
    if (encoded == null) return const <String>{};
    final decoded = jsonDecode(encoded);
    if (decoded is! List || decoded.any((value) => value is! String)) {
      throw const FormatException('Invalid declined session participants');
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
