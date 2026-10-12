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

/// A participant's media state. Starts from the current state, so the first
/// frame is already correct, then follows every change.

@ProviderFor(ParticipantMedia)
final participantMediaProvider = ParticipantMediaFamily._();

/// A participant's media state. Starts from the current state, so the first
/// frame is already correct, then follows every change.
final class ParticipantMediaProvider
    extends $NotifierProvider<ParticipantMedia, ParticipantMediaState> {
  /// A participant's media state. Starts from the current state, so the first
  /// frame is already correct, then follows every change.
  ParticipantMediaProvider._({
    required ParticipantMediaFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'participantMediaProvider',
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
  String debugGetCreateSourceHash() => _$participantMediaHash();

  @override
  String toString() {
    return r'participantMediaProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ParticipantMedia create() => ParticipantMedia();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ParticipantMediaState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ParticipantMediaState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ParticipantMediaProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$participantMediaHash() => r'c3d1ee51bc122a1705f10a99fcf771514cf0f515';

/// A participant's media state. Starts from the current state, so the first
/// frame is already correct, then follows every change.

final class ParticipantMediaFamily extends $Family
    with
        $ClassFamilyOverride<
          ParticipantMedia,
          ParticipantMediaState,
          ParticipantMediaState,
          ParticipantMediaState,
          String
        > {
  ParticipantMediaFamily._()
    : super(
        retry: null,
        name: r'participantMediaProvider',
        dependencies: <ProviderOrFamily>[roomMediaProvider],
        $allTransitiveDependencies: <ProviderOrFamily>[
          ParticipantMediaProvider.$allTransitiveDependencies0,
          ParticipantMediaProvider.$allTransitiveDependencies1,
          ParticipantMediaProvider.$allTransitiveDependencies2,
        ],
        isAutoDispose: true,
      );

  /// A participant's media state. Starts from the current state, so the first
  /// frame is already correct, then follows every change.

  ParticipantMediaProvider call(String identity) =>
      ParticipantMediaProvider._(argument: identity, from: this);

  @override
  String toString() => r'participantMediaProvider';
}

/// A participant's media state. Starts from the current state, so the first
/// frame is already correct, then follows every change.

abstract class _$ParticipantMedia extends $Notifier<ParticipantMediaState> {
  late final _$args = ref.$arg as String;
  String get identity => _$args;

  ParticipantMediaState build(String identity);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ParticipantMediaState, ParticipantMediaState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ParticipantMediaState, ParticipantMediaState>,
              ParticipantMediaState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
