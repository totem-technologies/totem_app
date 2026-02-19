// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(sessionToken)
final sessionTokenProvider = SessionTokenFamily._();

final class SessionTokenProvider
    extends $FunctionalProvider<AsyncValue<String>, String, FutureOr<String>>
    with $FutureModifier<String>, $FutureProvider<String> {
  SessionTokenProvider._({
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

String _$sessionTokenHash() => r'c633ea66c2c3a94ca1302948d43a7bc5d9734188';

final class SessionTokenFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<String>, String> {
  SessionTokenFamily._()
    : super(
        retry: null,
        name: r'sessionTokenProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SessionTokenProvider call(String sessionSlug) =>
      SessionTokenProvider._(argument: sessionSlug, from: this);

  @override
  String toString() => r'sessionTokenProvider';
}

@ProviderFor(removeParticipant)
final removeParticipantProvider = RemoveParticipantFamily._();

final class RemoveParticipantProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  RemoveParticipantProvider._({
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

String _$removeParticipantHash() => r'53bc1e4a0380a8a28f61a33309c19119fbea0047';

final class RemoveParticipantFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<void>, (String, String)> {
  RemoveParticipantFamily._()
    : super(
        retry: null,
        name: r'removeParticipantProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  RemoveParticipantProvider call(
    String sessionSlug,
    String participantIdentity,
  ) => RemoveParticipantProvider._(
    argument: (sessionSlug, participantIdentity),
    from: this,
  );

  @override
  String toString() => r'removeParticipantProvider';
}

/// Mutes a participant.
///
/// An error can be thrown if the participant is already muted.

@ProviderFor(muteParticipant)
final muteParticipantProvider = MuteParticipantFamily._();

/// Mutes a participant.
///
/// An error can be thrown if the participant is already muted.

final class MuteParticipantProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  /// Mutes a participant.
  ///
  /// An error can be thrown if the participant is already muted.
  MuteParticipantProvider._({
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

String _$muteParticipantHash() => r'd22a3a2438c3033ce363016a37acf250290e3e85';

/// Mutes a participant.
///
/// An error can be thrown if the participant is already muted.

final class MuteParticipantFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<void>, (String, String)> {
  MuteParticipantFamily._()
    : super(
        retry: null,
        name: r'muteParticipantProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Mutes a participant.
  ///
  /// An error can be thrown if the participant is already muted.

  MuteParticipantProvider call(
    String sessionSlug,
    String participantIdentity,
  ) => MuteParticipantProvider._(
    argument: (sessionSlug, participantIdentity),
    from: this,
  );

  @override
  String toString() => r'muteParticipantProvider';
}

@ProviderFor(muteEveryone)
final muteEveryoneProvider = MuteEveryoneFamily._();

final class MuteEveryoneProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  MuteEveryoneProvider._({
    required MuteEveryoneFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'muteEveryoneProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$muteEveryoneHash();

  @override
  String toString() {
    return r'muteEveryoneProvider'
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
    return muteEveryone(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is MuteEveryoneProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$muteEveryoneHash() => r'1ebecb1a4bcf013f945f7f1995527a8af80e1d71';

final class MuteEveryoneFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<void>, String> {
  MuteEveryoneFamily._()
    : super(
        retry: null,
        name: r'muteEveryoneProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  MuteEveryoneProvider call(String sessionSlug) =>
      MuteEveryoneProvider._(argument: sessionSlug, from: this);

  @override
  String toString() => r'muteEveryoneProvider';
}

@ProviderFor(passTotem)
final passTotemProvider = PassTotemFamily._();

final class PassTotemProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  PassTotemProvider._({
    required PassTotemFamily super.from,
    required (String, int) super.argument,
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
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<void> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<void> create(Ref ref) {
    final argument = this.argument as (String, int);
    return passTotem(ref, argument.$1, argument.$2);
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

String _$passTotemHash() => r'fc372df54e4c348f70513b8a94fdbf55f32209af';

final class PassTotemFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<void>, (String, int)> {
  PassTotemFamily._()
    : super(
        retry: null,
        name: r'passTotemProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  PassTotemProvider call(String sessionSlug, int lastSeenVersion) =>
      PassTotemProvider._(argument: (sessionSlug, lastSeenVersion), from: this);

  @override
  String toString() => r'passTotemProvider';
}

@ProviderFor(acceptTotem)
final acceptTotemProvider = AcceptTotemFamily._();

final class AcceptTotemProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  AcceptTotemProvider._({
    required AcceptTotemFamily super.from,
    required (String, int) super.argument,
  }) : super(
         retry: null,
         name: r'acceptTotemProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$acceptTotemHash();

  @override
  String toString() {
    return r'acceptTotemProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<void> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<void> create(Ref ref) {
    final argument = this.argument as (String, int);
    return acceptTotem(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is AcceptTotemProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$acceptTotemHash() => r'4672577c13112346951c7c775f634de47a5b9302';

final class AcceptTotemFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<void>, (String, int)> {
  AcceptTotemFamily._()
    : super(
        retry: null,
        name: r'acceptTotemProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AcceptTotemProvider call(String sessionSlug, int lastSeenVersion) =>
      AcceptTotemProvider._(
        argument: (sessionSlug, lastSeenVersion),
        from: this,
      );

  @override
  String toString() => r'acceptTotemProvider';
}

@ProviderFor(reorderParticipants)
final reorderParticipantsProvider = ReorderParticipantsFamily._();

final class ReorderParticipantsProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  ReorderParticipantsProvider._({
    required ReorderParticipantsFamily super.from,
    required (String, List<String>, int) super.argument,
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
    final argument = this.argument as (String, List<String>, int);
    return reorderParticipants(ref, argument.$1, argument.$2, argument.$3);
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
    r'85679a2f199e40271a00f4954a751ae5b3f2d260';

final class ReorderParticipantsFamily extends $Family
    with
        $FunctionalFamilyOverride<FutureOr<void>, (String, List<String>, int)> {
  ReorderParticipantsFamily._()
    : super(
        retry: null,
        name: r'reorderParticipantsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ReorderParticipantsProvider call(
    String sessionSlug,
    List<String> order,
    int lastSeenVersion,
  ) => ReorderParticipantsProvider._(
    argument: (sessionSlug, order, lastSeenVersion),
    from: this,
  );

  @override
  String toString() => r'reorderParticipantsProvider';
}

@ProviderFor(startSession)
final startSessionProvider = StartSessionFamily._();

final class StartSessionProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  StartSessionProvider._({
    required StartSessionFamily super.from,
    required (String, int) super.argument,
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
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<void> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<void> create(Ref ref) {
    final argument = this.argument as (String, int);
    return startSession(ref, argument.$1, argument.$2);
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

String _$startSessionHash() => r'77b57cb9cbd24c2d1f7821fb9718d719104211b0';

final class StartSessionFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<void>, (String, int)> {
  StartSessionFamily._()
    : super(
        retry: null,
        name: r'startSessionProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  StartSessionProvider call(String sessionSlug, int lastSeenVersion) =>
      StartSessionProvider._(
        argument: (sessionSlug, lastSeenVersion),
        from: this,
      );

  @override
  String toString() => r'startSessionProvider';
}

@ProviderFor(endSession)
final endSessionProvider = EndSessionFamily._();

final class EndSessionProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  EndSessionProvider._({
    required EndSessionFamily super.from,
    required (String, int) super.argument,
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
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<void> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<void> create(Ref ref) {
    final argument = this.argument as (String, int);
    return endSession(ref, argument.$1, argument.$2);
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

String _$endSessionHash() => r'176aea1b9eae7ed578145dca45462a49bc90f62f';

final class EndSessionFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<void>, (String, int)> {
  EndSessionFamily._()
    : super(
        retry: null,
        name: r'endSessionProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  EndSessionProvider call(String sessionSlug, int lastSeenVersion) =>
      EndSessionProvider._(
        argument: (sessionSlug, lastSeenVersion),
        from: this,
      );

  @override
  String toString() => r'endSessionProvider';
}

@ProviderFor(sessionFeedback)
final sessionFeedbackProvider = SessionFeedbackFamily._();

final class SessionFeedbackProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  SessionFeedbackProvider._({
    required SessionFeedbackFamily super.from,
    required (String, SessionFeedbackOptions, String?) super.argument,
  }) : super(
         retry: null,
         name: r'sessionFeedbackProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$sessionFeedbackHash();

  @override
  String toString() {
    return r'sessionFeedbackProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<void> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<void> create(Ref ref) {
    final argument = this.argument as (String, SessionFeedbackOptions, String?);
    return sessionFeedback(ref, argument.$1, argument.$2, argument.$3);
  }

  @override
  bool operator ==(Object other) {
    return other is SessionFeedbackProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$sessionFeedbackHash() => r'18524a4ffebbbb0ae3aa6211d8b9d9681b0f743a';

final class SessionFeedbackFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<void>,
          (String, SessionFeedbackOptions, String?)
        > {
  SessionFeedbackFamily._()
    : super(
        retry: null,
        name: r'sessionFeedbackProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SessionFeedbackProvider call(
    String sessionSlug,
    SessionFeedbackOptions feedback, [
    String? message,
  ]) => SessionFeedbackProvider._(
    argument: (sessionSlug, feedback, message),
    from: this,
  );

  @override
  String toString() => r'sessionFeedbackProvider';
}
