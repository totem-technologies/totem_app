// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(sessionToken)
const sessionTokenProvider = SessionTokenFamily._();

final class SessionTokenProvider
    extends $FunctionalProvider<AsyncValue<String>, String, FutureOr<String>>
    with $FutureModifier<String>, $FutureProvider<String> {
  const SessionTokenProvider._({
    required SessionTokenFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'sessionTokenProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$sessionTokenHash();

  @override
  String toString() {
    return r'sessionTokenProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<String> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String> create(Ref ref) {
    final argument = this.argument as String;
    return sessionToken(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SessionTokenProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$sessionTokenHash() => r'849b90e856cbe312b13624b9feab25626bf69a2d';

final class SessionTokenFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<String>, String> {
  const SessionTokenFamily._()
    : super(
        retry: null,
        name: r'sessionTokenProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SessionTokenProvider call(String eventSlug) =>
      SessionTokenProvider._(argument: eventSlug, from: this);

  @override
  String toString() => r'sessionTokenProvider';
}

@ProviderFor(removeParticipant)
const removeParticipantProvider = RemoveParticipantFamily._();

final class RemoveParticipantProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  const RemoveParticipantProvider._({
    required RemoveParticipantFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'removeParticipantProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$removeParticipantHash();

  @override
  String toString() {
    return r'removeParticipantProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<void> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<void> create(Ref ref) {
    final argument = this.argument as (String, String);
    return removeParticipant(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is RemoveParticipantProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$removeParticipantHash() => r'976553041a0fdd7ae21190a395af6940f2313ff3';

final class RemoveParticipantFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<void>, (String, String)> {
  const RemoveParticipantFamily._()
    : super(
        retry: null,
        name: r'removeParticipantProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  RemoveParticipantProvider call(
    String eventSlug,
    String participantIdentity,
  ) => RemoveParticipantProvider._(
    argument: (eventSlug, participantIdentity),
    from: this,
  );

  @override
  String toString() => r'removeParticipantProvider';
}

@ProviderFor(muteParticipant)
const muteParticipantProvider = MuteParticipantFamily._();

final class MuteParticipantProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  const MuteParticipantProvider._({
    required MuteParticipantFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'muteParticipantProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$muteParticipantHash();

  @override
  String toString() {
    return r'muteParticipantProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<void> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<void> create(Ref ref) {
    final argument = this.argument as (String, String);
    return muteParticipant(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is MuteParticipantProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$muteParticipantHash() => r'270bc7b1ee9ce164c570da193ec60908bea24083';

final class MuteParticipantFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<void>, (String, String)> {
  const MuteParticipantFamily._()
    : super(
        retry: null,
        name: r'muteParticipantProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  MuteParticipantProvider call(String eventSlug, String participantIdentity) =>
      MuteParticipantProvider._(
        argument: (eventSlug, participantIdentity),
        from: this,
      );

  @override
  String toString() => r'muteParticipantProvider';
}

@ProviderFor(passTotem)
const passTotemProvider = PassTotemFamily._();

final class PassTotemProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  const PassTotemProvider._({
    required PassTotemFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'passTotemProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$passTotemHash();

  @override
  String toString() {
    return r'passTotemProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<void> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<void> create(Ref ref) {
    final argument = this.argument as String;
    return passTotem(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PassTotemProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$passTotemHash() => r'06c72c9359f452adac98521b93d186da7099f5cc';

final class PassTotemFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<void>, String> {
  const PassTotemFamily._()
    : super(
        retry: null,
        name: r'passTotemProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  PassTotemProvider call(String eventSlug) =>
      PassTotemProvider._(argument: eventSlug, from: this);

  @override
  String toString() => r'passTotemProvider';
}

@ProviderFor(reorderParticipants)
const reorderParticipantsProvider = ReorderParticipantsFamily._();

final class ReorderParticipantsProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  const ReorderParticipantsProvider._({
    required ReorderParticipantsFamily super.from,
    required (String, LivekitMuteParticipantSchema) super.argument,
  }) : super(
         retry: null,
         name: r'reorderParticipantsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$reorderParticipantsHash();

  @override
  String toString() {
    return r'reorderParticipantsProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<void> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<void> create(Ref ref) {
    final argument = this.argument as (String, LivekitMuteParticipantSchema);
    return reorderParticipants(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is ReorderParticipantsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$reorderParticipantsHash() =>
    r'8377aee805ba362d65c10c8a0ba5d38f8e4011aa';

final class ReorderParticipantsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<void>,
          (String, LivekitMuteParticipantSchema)
        > {
  const ReorderParticipantsFamily._()
    : super(
        retry: null,
        name: r'reorderParticipantsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ReorderParticipantsProvider call(
    String eventSlug,
    LivekitMuteParticipantSchema order,
  ) => ReorderParticipantsProvider._(argument: (eventSlug, order), from: this);

  @override
  String toString() => r'reorderParticipantsProvider';
}

@ProviderFor(startSession)
const startSessionProvider = StartSessionFamily._();

final class StartSessionProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  const StartSessionProvider._({
    required StartSessionFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'startSessionProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$startSessionHash();

  @override
  String toString() {
    return r'startSessionProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<void> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<void> create(Ref ref) {
    final argument = this.argument as String;
    return startSession(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is StartSessionProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$startSessionHash() => r'6c9b93d85ad23f519351a3568ed35e78e61670b6';

final class StartSessionFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<void>, String> {
  const StartSessionFamily._()
    : super(
        retry: null,
        name: r'startSessionProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  StartSessionProvider call(String eventSlug) =>
      StartSessionProvider._(argument: eventSlug, from: this);

  @override
  String toString() => r'startSessionProvider';
}

@ProviderFor(endSession)
const endSessionProvider = EndSessionFamily._();

final class EndSessionProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  const EndSessionProvider._({
    required EndSessionFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'endSessionProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$endSessionHash();

  @override
  String toString() {
    return r'endSessionProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<void> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<void> create(Ref ref) {
    final argument = this.argument as String;
    return endSession(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is EndSessionProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$endSessionHash() => r'106e50abd5fa9f003c9c9ab16ec86d792842335d';

final class EndSessionFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<void>, String> {
  const EndSessionFamily._()
    : super(
        retry: null,
        name: r'endSessionProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  EndSessionProvider call(String eventSlug) =>
      EndSessionProvider._(argument: eventSlug, from: this);

  @override
  String toString() => r'endSessionProvider';
}
