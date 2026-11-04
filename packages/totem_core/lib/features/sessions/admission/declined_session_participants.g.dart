// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'declined_session_participants.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(sessionAdmissionPreferences)
final sessionAdmissionPreferencesProvider =
    SessionAdmissionPreferencesProvider._();

final class SessionAdmissionPreferencesProvider
    extends
        $FunctionalProvider<
          AsyncValue<SessionAdmissionPreferences>,
          SessionAdmissionPreferences,
          FutureOr<SessionAdmissionPreferences>
        >
    with
        $FutureModifier<SessionAdmissionPreferences>,
        $FutureProvider<SessionAdmissionPreferences> {
  SessionAdmissionPreferencesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionAdmissionPreferencesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionAdmissionPreferencesHash();

  @$internal
  @override
  $FutureProviderElement<SessionAdmissionPreferences> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SessionAdmissionPreferences> create(Ref ref) {
    return sessionAdmissionPreferences(ref);
  }
}

String _$sessionAdmissionPreferencesHash() =>
    r'7d236853c0f918825d32956e1eee4be2b922cddd';

@ProviderFor(DeclinedSessionParticipants)
final declinedSessionParticipantsProvider =
    DeclinedSessionParticipantsFamily._();

final class DeclinedSessionParticipantsProvider
    extends $AsyncNotifierProvider<DeclinedSessionParticipants, Set<String>> {
  DeclinedSessionParticipantsProvider._({
    required DeclinedSessionParticipantsFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'declinedSessionParticipantsProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$declinedSessionParticipantsHash();

  @override
  String toString() {
    return r'declinedSessionParticipantsProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  DeclinedSessionParticipants create() => DeclinedSessionParticipants();

  @override
  bool operator ==(Object other) {
    return other is DeclinedSessionParticipantsProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$declinedSessionParticipantsHash() =>
    r'dd849baffa28cab2a35cba558ea1bade44a67a64';

final class DeclinedSessionParticipantsFamily extends $Family
    with
        $ClassFamilyOverride<
          DeclinedSessionParticipants,
          AsyncValue<Set<String>>,
          Set<String>,
          FutureOr<Set<String>>,
          (String, String)
        > {
  DeclinedSessionParticipantsFamily._()
    : super(
        retry: null,
        name: r'declinedSessionParticipantsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  DeclinedSessionParticipantsProvider call(
    String sessionSlug,
    String keeperIdentity,
  ) => DeclinedSessionParticipantsProvider._(
    argument: (sessionSlug, keeperIdentity),
    from: this,
  );

  @override
  String toString() => r'declinedSessionParticipantsProvider';
}

abstract class _$DeclinedSessionParticipants
    extends $AsyncNotifier<Set<String>> {
  late final _$args = ref.$arg as (String, String);
  String get sessionSlug => _$args.$1;
  String get keeperIdentity => _$args.$2;

  FutureOr<Set<String>> build(String sessionSlug, String keeperIdentity);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<Set<String>>, Set<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<Set<String>>, Set<String>>,
              AsyncValue<Set<String>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args.$1, _$args.$2));
  }
}
