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

String _$sessionTokenHash() => r'b599d7329d4615cba92d18375fb508ea8dc5da19';

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

String _$removeParticipantHash() => r'04281cd7314c75590f956267eb74b78d566f4114';

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

/// Mutes a participant.
///
/// An error can be thrown if the participant is already muted.

@ProviderFor(muteParticipant)
const muteParticipantProvider = MuteParticipantFamily._();

/// Mutes a participant.
///
/// An error can be thrown if the participant is already muted.

final class MuteParticipantProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  /// Mutes a participant.
  ///
  /// An error can be thrown if the participant is already muted.
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

String _$muteParticipantHash() => r'16cc9d401dd4ce042df99f415da9db59210d9cf5';

/// Mutes a participant.
///
/// An error can be thrown if the participant is already muted.

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
const muteEveryoneProvider = MuteEveryoneFamily._();

final class MuteEveryoneProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  const MuteEveryoneProvider._({
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

String _$muteEveryoneHash() => r'eb83b27ea8c9e9b82d1602b5b19f370c86c31dea';

final class MuteEveryoneFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<void>, String> {
  const MuteEveryoneFamily._()
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

String _$passTotemHash() => r'0c7fb482155b1f3d45a792d1b58580b713686c3e';

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
    r'9b41757b5e091612e66a1e539e5c794f46b0f0f9';

final class ReorderParticipantsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<void>, (String, List<String>)> {
  const ReorderParticipantsFamily._()
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

String _$startSessionHash() => r'617d570d06f8422fde4ee265a73bdfef6496662a';

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

String _$endSessionHash() => r'f4a9896ded183609b5e8a277b4d96e4cdd8da9af';

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

@ProviderFor(sessionFeedback)
const sessionFeedbackProvider = SessionFeedbackFamily._();

final class SessionFeedbackProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  const SessionFeedbackProvider._({
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

String _$sessionFeedbackHash() => r'a69c6bc5e33ee9a672ac74c1d7d56009ac6f32bd';

final class SessionFeedbackFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<void>,
          (String, SessionFeedbackOptions, String?)
        > {
  const SessionFeedbackFamily._()
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
