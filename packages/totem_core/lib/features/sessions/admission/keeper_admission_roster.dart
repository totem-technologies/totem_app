import 'dart:async';
import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_core/features/sessions/admission/admission_controllers.dart';
import 'package:totem_core/features/sessions/admission/admission_storage_queue.dart';
import 'package:totem_core/features/sessions/admission/declined_session_participants.dart';

part 'keeper_admission_roster.g.dart';

@riverpod
class KeeperAdmissionRoster extends _$KeeperAdmissionRoster {
  static const _storagePrefix = 'session_admission_keeper_roster';
  static const _schemaVersion = 1;
  static const _maxIdentityLength = 256;
  static const _maxRevision = 9007199254740991;

  Future<void> _writes = Future.value();

  var _initializationGeneration = 0;
  var _loadedGeneration = 0;
  SessionAdmissionPreferences? _preferences;
  KeeperAdmissionRosterStore? _store;
  String? _storageKey;
  late String _sessionSlug;
  late String _keeperIdentity;

  @override
  Future<KeeperAdmissionRosterStore> build(
    String sessionSlug,
    String keeperIdentity,
  ) {
    _validateSession(sessionSlug, keeperIdentity);
    _sessionSlug = sessionSlug;
    _keeperIdentity = keeperIdentity;
    final generation = ++_initializationGeneration;
    _loadedGeneration = 0;
    _preferences = null;
    _store = null;
    _storageKey = null;
    return _initialize(sessionSlug, keeperIdentity, generation);
  }

  Future<void> persist() {
    final snapshot = _snapshot(_loadedStore());
    return _enqueue(snapshot);
  }

  /// Refuse a late writer captured by a superseded admission owner.
  Future<void> persistStore(KeeperAdmissionRosterStore owner) {
    if (!identical(_loadedStore(), owner)) {
      throw StateError('Keeper admission roster owner was replaced');
    }
    return _enqueue(_snapshot(owner));
  }

  KeeperAdmissionPersistence capturePersistence(
    KeeperAdmissionRosterStore owner,
  ) {
    if (!identical(_loadedStore(), owner)) {
      throw StateError('Roster owner replaced');
    }
    final preferences = _preferences!;
    final key = _storageKey!;
    return KeeperAdmissionPersistence._(
      () => _enqueueCaptured(preferences, key, _snapshot(owner)),
      () async {
        await _enqueueCaptured(preferences, key, null);
        owner.clear();
      },
    );
  }

  Future<void> clear() async {
    final store = _loadedStore();
    await _enqueue(null);
    store.clear();
    if (ref.mounted) state = AsyncData(store);
  }

  Future<void> resetCorruptData() {
    if (state.error is! CorruptSessionAdmissionData) {
      throw StateError('Keeper admission roster is not corrupt');
    }
    final key = _storageKeyFor(_sessionSlug, _keeperIdentity);
    final link = ref.keepAlive();
    final preferences = ref.read(sessionAdmissionPreferencesProvider.future);
    final operation = _writes.then(
      (_) => AdmissionStorageQueue.run(key, () async {
        if (!await (await preferences).remove(key)) {
          throw StateError('Could not clear keeper admission roster');
        }
        if (ref.mounted) ref.invalidateSelf();
      }),
    );
    _writes = operation.catchError((Object _) {});
    return operation.whenComplete(link.close);
  }

  Future<KeeperAdmissionRosterStore> _initialize(
    String sessionSlug,
    String keeperIdentity,
    int generation,
  ) => ref.watch(sessionAdmissionPreferencesProvider.future).then((
    preferences,
  ) async {
    final storageKey = _storageKeyFor(sessionSlug, keeperIdentity);
    final store = await AdmissionStorageQueue.run(
      storageKey,
      () async => _readStore(preferences, storageKey, keeperIdentity),
    );
    if (generation == _initializationGeneration) {
      _preferences = preferences;
      _store = store;
      _storageKey = storageKey;
      _loadedGeneration = generation;
    }
    return store;
  });

  Future<void> _enqueue(_RosterSnapshot? snapshot) {
    final preferences = _preferences;
    final storageKey = _storageKey;
    if (preferences == null || storageKey == null) {
      throw StateError('Keeper admission roster is not initialized');
    }
    final link = ref.keepAlive();
    return _enqueueCaptured(
      preferences,
      storageKey,
      snapshot,
    ).whenComplete(link.close);
  }

  Future<void> _enqueueCaptured(
    SessionAdmissionPreferences preferences,
    String storageKey,
    _RosterSnapshot? snapshot,
  ) {
    final operation = AdmissionStorageQueue.run(storageKey, () async {
      final persisted = snapshot == null
          ? await preferences.remove(storageKey)
          : await preferences.setString(storageKey, snapshot.encode());
      if (!persisted) {
        throw StateError('Could not persist keeper admission roster');
      }
    });
    _writes = operation.catchError((Object _) {});
    return operation;
  }

  KeeperAdmissionRosterStore _loadedStore() {
    final store = _store;
    if (store == null || _loadedGeneration != _initializationGeneration) {
      throw StateError('Keeper admission roster is not initialized');
    }
    return store;
  }

  KeeperAdmissionRosterStore _readStore(
    SessionAdmissionPreferences preferences,
    String storageKey,
    String keeperIdentity,
  ) {
    final encoded = preferences.getString(storageKey);
    if (encoded == null) return KeeperAdmissionRosterStore();

    final Object? decoded;
    try {
      decoded = jsonDecode(encoded);
    } on FormatException {
      throw CorruptSessionAdmissionData();
    }
    if (decoded is! Map<String, Object?> ||
        decoded['version'] != _schemaVersion ||
        decoded['generation'] is! String ||
        decoded['revision'] is! int ||
        decoded['members'] is! List ||
        decoded['awaitingReadiness'] is! List ||
        (decoded.containsKey('revoked') && decoded['revoked'] is! List)) {
      throw CorruptSessionAdmissionData();
    }

    final generation = decoded['generation']! as String;
    final revision = decoded['revision']! as int;
    final members = _readIdentities(
      decoded['members']! as List<Object?>,
      keeperIdentity,
    );
    final awaitingReadiness = _readIdentities(
      decoded['awaitingReadiness']! as List<Object?>,
      keeperIdentity,
    );
    if (generation.trim().isEmpty ||
        revision < 0 ||
        revision > _maxRevision ||
        !members.containsAll(awaitingReadiness)) {
      throw CorruptSessionAdmissionData();
    }

    return KeeperAdmissionRosterStore(keeperGeneration: generation)
      ..revoked.addAll(
        _readIdentities(
          (decoded['revoked'] as List<Object?>?) ?? const [],
          keeperIdentity,
        ),
      )
      ..replace(members, revision, awaitingReadiness: awaitingReadiness);
  }

  Set<String> _readIdentities(List<Object?> values, String keeperIdentity) {
    if (values.any((value) => value is! String)) {
      throw CorruptSessionAdmissionData();
    }
    final identities = values.cast<String>().toSet();
    if (identities.length != values.length ||
        identities.any(
          (identity) =>
              identity.trim().isEmpty ||
              identity.length > _maxIdentityLength ||
              identity == keeperIdentity,
        )) {
      throw CorruptSessionAdmissionData();
    }
    return identities;
  }

  _RosterSnapshot _snapshot(KeeperAdmissionRosterStore store) {
    final members = store.members.toSet().toList()..sort();
    final awaitingReadiness = store.awaitingReadiness.toSet().toList()..sort();
    return _RosterSnapshot(
      generation: store.keeperGeneration,
      revision: store.revision,
      members: members,
      awaitingReadiness: awaitingReadiness,
      revoked: store.revoked.toList()..sort(),
    );
  }

  String _storageKeyFor(String sessionSlug, String keeperIdentity) =>
      '$_storagePrefix:${Uri.encodeComponent(sessionSlug)}:'
      '${Uri.encodeComponent(keeperIdentity)}';

  void _validateSession(String sessionSlug, String keeperIdentity) {
    if (sessionSlug.trim().isEmpty || keeperIdentity.trim().isEmpty) {
      throw ArgumentError('Session slug and keeper identity must not be blank');
    }
  }
}

final class _RosterSnapshot {
  const _RosterSnapshot({
    required this.generation,
    required this.revision,
    required this.members,
    required this.awaitingReadiness,
    required this.revoked,
  });

  final String generation;
  final int revision;
  final List<String> members;
  final List<String> awaitingReadiness;
  final List<String> revoked;

  String encode() => jsonEncode({
    'version': KeeperAdmissionRoster._schemaVersion,
    'generation': generation,
    'revision': revision,
    'members': members,
    'awaitingReadiness': awaitingReadiness,
    'revoked': revoked,
  });
}

/// A session's captured writer is independent of Ref disposal. Releasing it
/// fences late callbacks; already-started writes remain in the storage queue.
class KeeperAdmissionPersistence {
  KeeperAdmissionPersistence._(this._save, this._clear);
  final Future<void> Function() _save;
  final Future<void> Function() _clear;
  bool _released = false;
  Future<void> persist() {
    if (_released) throw StateError('Admission persistence owner released');
    return _save();
  }

  Future<void> clear() {
    if (_released) throw StateError('Admission persistence owner released');
    return _clear();
  }

  void release() => _released = true;
}
