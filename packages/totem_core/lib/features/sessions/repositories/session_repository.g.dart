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

String _$sessionTokenHash() => r'212c0807291d25217b97ca9bfdfbfebf60bb00cd';

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

String _$removeParticipantHash() => r'3791db04e888e43ee11791727578e9beb0e23bd6';

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

String _$muteParticipantHash() => r'352bdfacd9562d7082e33c83f437b2d8f491d82a';

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

String _$muteEveryoneHash() => r'cf94b112925cc166b5526abd469b81f735acc626';

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

/// Disables the camera of a participant.
///
/// An error can be thrown if the participant camera is already disabled.

@ProviderFor(disableParticipantCamera)
final disableParticipantCameraProvider = DisableParticipantCameraFamily._();

/// Disables the camera of a participant.
///
/// An error can be thrown if the participant camera is already disabled.

final class DisableParticipantCameraProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  /// Disables the camera of a participant.
  ///
  /// An error can be thrown if the participant camera is already disabled.
  DisableParticipantCameraProvider._({
    required DisableParticipantCameraFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'disableParticipantCameraProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$disableParticipantCameraHash();

  @override
  String toString() {
    return r'disableParticipantCameraProvider'
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
    return disableParticipantCamera(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is DisableParticipantCameraProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$disableParticipantCameraHash() =>
    r'f1200b246f251ac999e89515ad3655bf9008c0d2';

/// Disables the camera of a participant.
///
/// An error can be thrown if the participant camera is already disabled.

final class DisableParticipantCameraFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<void>, (String, String)> {
  DisableParticipantCameraFamily._()
    : super(
        retry: null,
        name: r'disableParticipantCameraProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Disables the camera of a participant.
  ///
  /// An error can be thrown if the participant camera is already disabled.

  DisableParticipantCameraProvider call(
    String sessionSlug,
    String participantIdentity,
  ) => DisableParticipantCameraProvider._(
    argument: (sessionSlug, participantIdentity),
    from: this,
  );

  @override
  String toString() => r'disableParticipantCameraProvider';
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
    required (String, int, {String? roundMessage}) super.argument,
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
    final argument = this.argument as (String, int, {String? roundMessage});
    return passTotem(
      ref,
      argument.$1,
      argument.$2,
      roundMessage: argument.roundMessage,
    );
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

String _$passTotemHash() => r'ad90e365d9c9833a0e012eba7b5e25d945c8eb53';

final class PassTotemFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<RoomState>,
          (String, int, {String? roundMessage})
        > {
  PassTotemFamily._()
    : super(
        retry: null,
        name: r'passTotemProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  PassTotemProvider call(
    String sessionSlug,
    int lastSeenVersion, {
    String? roundMessage,
  }) => PassTotemProvider._(
    argument: (sessionSlug, lastSeenVersion, roundMessage: roundMessage),
    from: this,
  );

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

String _$acceptTotemHash() => r'f3b295f5bdfa52ae18d512394cf52d5d9d55bd72';

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

String _$forcePassTotemHash() => r'00d5d9be991f70a28a8d896e395c36be6f1cef1f';

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
    r'62d5971c6e18531e2722f0410d13da347508311b';

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

String _$startSessionHash() => r'4180b185f2f0e62b074962baa840947447032494';

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

String _$endSessionHash() => r'344a5d52fbe2dc73d991a685ba7968fd874880f3';

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

String _$banParticipantHash() => r'20c1513b8d3fd84c68301dee0dff037d3d02f8e2';

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

String _$unbanParticipantHash() => r'b81ead4c121728589d929460e9caa062e64a0678';

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

String _$sessionFeedbackHash() => r'796b36796876ef3d8f2a71f0d723c05ee71b3fe1';

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
