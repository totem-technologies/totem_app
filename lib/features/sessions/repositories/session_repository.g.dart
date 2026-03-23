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
    extends
        $FunctionalProvider<
          AsyncValue<JoinResponse>,
          JoinResponse,
          FutureOr<JoinResponse>
        >
    with $FutureModifier<JoinResponse>, $FutureProvider<JoinResponse> {
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
  $FutureProviderElement<JoinResponse> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<JoinResponse> create(Ref ref) {
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

String _$sessionTokenHash() => r'a4a4f055cffb447c1aa6acefd76c72b864762c33';

final class SessionTokenFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<JoinResponse>, String> {
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

String _$muteEveryoneHash() => r'7e05f7a4182145923da5076aa6de2ac11a39ffb1';

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
    extends
        $FunctionalProvider<
          AsyncValue<RoomState>,
          RoomState,
          FutureOr<RoomState>
        >
    with $FutureModifier<RoomState>, $FutureProvider<RoomState> {
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
  $FutureProviderElement<RoomState> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<RoomState> create(Ref ref) {
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

String _$passTotemHash() => r'a269f554c88089b345cc8950a24f8fb383b75c2a';

final class PassTotemFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<RoomState>, (String, int)> {
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
    extends
        $FunctionalProvider<
          AsyncValue<RoomState>,
          RoomState,
          FutureOr<RoomState>
        >
    with $FutureModifier<RoomState>, $FutureProvider<RoomState> {
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
  $FutureProviderElement<RoomState> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<RoomState> create(Ref ref) {
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

String _$acceptTotemHash() => r'a42dab5885d2d618608399aace2abe2e39599127';

final class AcceptTotemFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<RoomState>, (String, int)> {
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

@ProviderFor(forcePassTotem)
final forcePassTotemProvider = ForcePassTotemFamily._();

final class ForcePassTotemProvider
    extends
        $FunctionalProvider<
          AsyncValue<RoomState>,
          RoomState,
          FutureOr<RoomState>
        >
    with $FutureModifier<RoomState>, $FutureProvider<RoomState> {
  ForcePassTotemProvider._({
    required ForcePassTotemFamily super.from,
    required (String, int) super.argument,
  }) : super(
         retry: null,
         name: r'forcePassTotemProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$forcePassTotemHash();

  @override
  String toString() {
    return r'forcePassTotemProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<RoomState> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<RoomState> create(Ref ref) {
    final argument = this.argument as (String, int);
    return forcePassTotem(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is ForcePassTotemProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$forcePassTotemHash() => r'098b856a7a64d41a32bceb2e652aef8af45b17dc';

final class ForcePassTotemFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<RoomState>, (String, int)> {
  ForcePassTotemFamily._()
    : super(
        retry: null,
        name: r'forcePassTotemProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ForcePassTotemProvider call(String sessionSlug, int lastSeenVersion) =>
      ForcePassTotemProvider._(
        argument: (sessionSlug, lastSeenVersion),
        from: this,
      );

  @override
  String toString() => r'forcePassTotemProvider';
}

@ProviderFor(reorderParticipants)
final reorderParticipantsProvider = ReorderParticipantsFamily._();

final class ReorderParticipantsProvider
    extends
        $FunctionalProvider<
          AsyncValue<RoomState>,
          RoomState,
          FutureOr<RoomState>
        >
    with $FutureModifier<RoomState>, $FutureProvider<RoomState> {
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
  $FutureProviderElement<RoomState> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<RoomState> create(Ref ref) {
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
    r'6d18a35a8f74dde5d55069a15a2a4065e764ffb5';

final class ReorderParticipantsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<RoomState>,
          (String, List<String>, int)
        > {
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
    extends
        $FunctionalProvider<
          AsyncValue<RoomState>,
          RoomState,
          FutureOr<RoomState>
        >
    with $FutureModifier<RoomState>, $FutureProvider<RoomState> {
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
  $FutureProviderElement<RoomState> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<RoomState> create(Ref ref) {
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

String _$startSessionHash() => r'3e5cf6a4ad5c0113e3677f22aaab64e3ce99e8ff';

final class StartSessionFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<RoomState>, (String, int)> {
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
    extends
        $FunctionalProvider<
          AsyncValue<RoomState>,
          RoomState,
          FutureOr<RoomState>
        >
    with $FutureModifier<RoomState>, $FutureProvider<RoomState> {
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
  $FutureProviderElement<RoomState> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<RoomState> create(Ref ref) {
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

String _$endSessionHash() => r'32dc792a5ecce382021036e3eb7737a6db8837af';

final class EndSessionFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<RoomState>, (String, int)> {
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

@ProviderFor(banParticipant)
final banParticipantProvider = BanParticipantFamily._();

final class BanParticipantProvider
    extends
        $FunctionalProvider<
          AsyncValue<RoomState>,
          RoomState,
          FutureOr<RoomState>
        >
    with $FutureModifier<RoomState>, $FutureProvider<RoomState> {
  BanParticipantProvider._({
    required BanParticipantFamily super.from,
    required (String, String, int) super.argument,
  }) : super(
         retry: null,
         name: r'banParticipantProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$banParticipantHash();

  @override
  String toString() {
    return r'banParticipantProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<RoomState> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<RoomState> create(Ref ref) {
    final argument = this.argument as (String, String, int);
    return banParticipant(ref, argument.$1, argument.$2, argument.$3);
  }

  @override
  bool operator ==(Object other) {
    return other is BanParticipantProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$banParticipantHash() => r'5ef016ab602c346c720922498dfe5830bb382e28';

final class BanParticipantFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<RoomState>, (String, String, int)> {
  BanParticipantFamily._()
    : super(
        retry: null,
        name: r'banParticipantProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  BanParticipantProvider call(
    String sessionSlug,
    String participantSlug,
    int lastSeenVersion,
  ) => BanParticipantProvider._(
    argument: (sessionSlug, participantSlug, lastSeenVersion),
    from: this,
  );

  @override
  String toString() => r'banParticipantProvider';
}

@ProviderFor(unbanParticipant)
final unbanParticipantProvider = UnbanParticipantFamily._();

final class UnbanParticipantProvider
    extends
        $FunctionalProvider<
          AsyncValue<RoomState>,
          RoomState,
          FutureOr<RoomState>
        >
    with $FutureModifier<RoomState>, $FutureProvider<RoomState> {
  UnbanParticipantProvider._({
    required UnbanParticipantFamily super.from,
    required (String, String, int) super.argument,
  }) : super(
         retry: null,
         name: r'unbanParticipantProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$unbanParticipantHash();

  @override
  String toString() {
    return r'unbanParticipantProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<RoomState> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<RoomState> create(Ref ref) {
    final argument = this.argument as (String, String, int);
    return unbanParticipant(ref, argument.$1, argument.$2, argument.$3);
  }

  @override
  bool operator ==(Object other) {
    return other is UnbanParticipantProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$unbanParticipantHash() => r'c11957da27f8554b5417ef93d97f809c60ad882d';

final class UnbanParticipantFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<RoomState>, (String, String, int)> {
  UnbanParticipantFamily._()
    : super(
        retry: null,
        name: r'unbanParticipantProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  UnbanParticipantProvider call(
    String sessionSlug,
    String participantSlug,
    int lastSeenVersion,
  ) => UnbanParticipantProvider._(
    argument: (sessionSlug, participantSlug, lastSeenVersion),
    from: this,
  );

  @override
  String toString() => r'unbanParticipantProvider';
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

String _$sessionFeedbackHash() => r'8807e946ec9f45977c0a87b09f8f314d233b1379';

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
