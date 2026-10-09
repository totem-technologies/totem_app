// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'room_media_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Media for the current session's room, or null outside a session.

@ProviderFor(roomMedia)
final roomMediaProvider = RoomMediaProvider._();

/// Media for the current session's room, or null outside a session.

final class RoomMediaProvider
    extends $FunctionalProvider<RoomMedia?, RoomMedia?, RoomMedia?>
    with $Provider<RoomMedia?> {
  /// Media for the current session's room, or null outside a session.
  RoomMediaProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'roomMediaProvider',
        isAutoDispose: true,
        dependencies: <ProviderOrFamily>[currentSessionProvider],
        $allTransitiveDependencies: <ProviderOrFamily>[
          RoomMediaProvider.$allTransitiveDependencies0,
          RoomMediaProvider.$allTransitiveDependencies1,
        ],
      );

  static final $allTransitiveDependencies0 = currentSessionProvider;
  static final $allTransitiveDependencies1 =
      CurrentSessionProvider.$allTransitiveDependencies0;

  @override
  String debugGetCreateSourceHash() => _$roomMediaHash();

  @$internal
  @override
  $ProviderElement<RoomMedia?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RoomMedia? create(Ref ref) {
    return roomMedia(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RoomMedia? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RoomMedia?>(value),
    );
  }
}

String _$roomMediaHash() => r'a1c25d6bb539947f13473a92a407ea51ec3a1c9e';

@ProviderFor(participantMediaState)
final participantMediaStateProvider = ParticipantMediaStateFamily._();

final class ParticipantMediaStateProvider
    extends
        $FunctionalProvider<
          AsyncValue<ParticipantMediaState>,
          ParticipantMediaState,
          Stream<ParticipantMediaState>
        >
    with
        $FutureModifier<ParticipantMediaState>,
        $StreamProvider<ParticipantMediaState> {
  ParticipantMediaStateProvider._({
    required ParticipantMediaStateFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'participantMediaStateProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  static final $allTransitiveDependencies0 = roomMediaProvider;
  static final $allTransitiveDependencies1 =
      RoomMediaProvider.$allTransitiveDependencies0;
  static final $allTransitiveDependencies2 =
      RoomMediaProvider.$allTransitiveDependencies1;

  @override
  String debugGetCreateSourceHash() => _$participantMediaStateHash();

  @override
  String toString() {
    return r'participantMediaStateProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<ParticipantMediaState> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<ParticipantMediaState> create(Ref ref) {
    final argument = this.argument as String;
    return participantMediaState(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ParticipantMediaStateProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$participantMediaStateHash() =>
    r'b8ec8fdb73141224bb801cf258c2c7e9aa4fc583';

final class ParticipantMediaStateFamily extends $Family
    with $FunctionalFamilyOverride<Stream<ParticipantMediaState>, String> {
  ParticipantMediaStateFamily._()
    : super(
        retry: null,
        name: r'participantMediaStateProvider',
        dependencies: <ProviderOrFamily>[roomMediaProvider],
        $allTransitiveDependencies: <ProviderOrFamily>[
          ParticipantMediaStateProvider.$allTransitiveDependencies0,
          ParticipantMediaStateProvider.$allTransitiveDependencies1,
          ParticipantMediaStateProvider.$allTransitiveDependencies2,
        ],
        isAutoDispose: true,
      );

  ParticipantMediaStateProvider call(String identity) =>
      ParticipantMediaStateProvider._(argument: identity, from: this);

  @override
  String toString() => r'participantMediaStateProvider';
}
