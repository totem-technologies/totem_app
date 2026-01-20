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

String _$sessionTokenHash() => r'b599d7329d4615cba92d18375fb508ea8dc5da19';

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

  SessionTokenProvider call(String eventSlug) =>
      SessionTokenProvider._(argument: eventSlug, from: this);

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

String _$removeParticipantHash() => r'11040d236aca40d13d90c9981ec87dea97055af9';

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
    String eventSlug,
    String participantIdentity,
  ) => RemoveParticipantProvider._(
    argument: (eventSlug, participantIdentity),
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

String _$muteParticipantHash() => r'16cc9d401dd4ce042df99f415da9db59210d9cf5';

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

  MuteParticipantProvider call(String eventSlug, String participantIdentity) =>
      MuteParticipantProvider._(
        argument: (eventSlug, participantIdentity),
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

String _$muteEveryoneHash() => r'0e038e9c31b8a2784f8311923ed78100832ce311';

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

  MuteEveryoneProvider call(String eventSlug) =>
      MuteEveryoneProvider._(argument: eventSlug, from: this);

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

String _$passTotemHash() => r'aeb11ba4153fe8c36831b876f6d29a0cd5689087';

final class PassTotemFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<void>, String> {
  PassTotemFamily._()
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

@ProviderFor(acceptTotem)
final acceptTotemProvider = AcceptTotemFamily._();

final class AcceptTotemProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  AcceptTotemProvider._({
    required AcceptTotemFamily super.from,
    required String super.argument,
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
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<void> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<void> create(Ref ref) {
    final argument = this.argument as String;
    return acceptTotem(ref, argument);
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

String _$acceptTotemHash() => r'22ac74eb26369a8fb8452391f06c6981bfbfc930';

final class AcceptTotemFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<void>, String> {
  AcceptTotemFamily._()
    : super(
        retry: null,
        name: r'acceptTotemProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AcceptTotemProvider call(String eventSlug) =>
      AcceptTotemProvider._(argument: eventSlug, from: this);

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
    required (String, List<String>) super.argument,
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
    final argument = this.argument as (String, List<String>);
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
    r'086f9c1094c0a701204fe49ac633abf15599cd41';

final class ReorderParticipantsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<void>, (String, List<String>)> {
  ReorderParticipantsFamily._()
    : super(
        retry: null,
        name: r'reorderParticipantsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ReorderParticipantsProvider call(String eventSlug, List<String> order) =>
      ReorderParticipantsProvider._(argument: (eventSlug, order), from: this);

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

String _$startSessionHash() => r'cf61d25c282b2bca7e85dd4d70a196f3849cd908';

final class StartSessionFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<void>, String> {
  StartSessionFamily._()
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
final endSessionProvider = EndSessionFamily._();

final class EndSessionProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  EndSessionProvider._({
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

String _$endSessionHash() => r'f4a9896ded183609b5e8a277b4d96e4cdd8da9af';

final class EndSessionFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<void>, String> {
  EndSessionFamily._()
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

String _$sessionFeedbackHash() => r'611b791e9cded8a563fe24c8f670e7ea4adde90f';

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
    String eventSlug,
    SessionFeedbackOptions feedback, [
    String? message,
  ]) => SessionFeedbackProvider._(
    argument: (eventSlug, feedback, message),
    from: this,
  );

  @override
  String toString() => r'sessionFeedbackProvider';
}
