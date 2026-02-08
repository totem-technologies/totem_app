// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_scope_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider that will be overridden at room scope.
/// Returns the current session options for the active room.

@ProviderFor(sessionScope)
final sessionScopeProvider = SessionScopeProvider._();

/// Provider that will be overridden at room scope.
/// Returns the current session options for the active room.

final class SessionScopeProvider
    extends
        $FunctionalProvider<SessionOptions?, SessionOptions?, SessionOptions?>
    with $Provider<SessionOptions?> {
  /// Provider that will be overridden at room scope.
  /// Returns the current session options for the active room.
  SessionScopeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionScopeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionScopeHash();

  @$internal
  @override
  $ProviderElement<SessionOptions?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SessionOptions? create(Ref ref) {
    return sessionScope(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionOptions? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionOptions?>(value),
    );
  }
}

String _$sessionScopeHash() => r'e04113d280234c4d312c85168afffda12c534adc';

/// Convenience provider to get the current session notifier.

@ProviderFor(currentSession)
final currentSessionProvider = CurrentSessionProvider._();

/// Convenience provider to get the current session notifier.

final class CurrentSessionProvider
    extends $FunctionalProvider<Session?, Session?, Session?>
    with $Provider<Session?> {
  /// Convenience provider to get the current session notifier.
  CurrentSessionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentSessionProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentSessionHash();

  @$internal
  @override
  $ProviderElement<Session?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Session? create(Ref ref) {
    return currentSession(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Session? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Session?>(value),
    );
  }
}

String _$currentSessionHash() => r'ec443bb0a8faa45cbdcfc07b1e7b2b2c2b2721e0';

/// Convenience provider to get the current session state.

@ProviderFor(currentSessionState)
final currentSessionStateProvider = CurrentSessionStateProvider._();

/// Convenience provider to get the current session state.

final class CurrentSessionStateProvider
    extends
        $FunctionalProvider<
          SessionRoomState?,
          SessionRoomState?,
          SessionRoomState?
        >
    with $Provider<SessionRoomState?> {
  /// Convenience provider to get the current session state.
  CurrentSessionStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentSessionStateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentSessionStateHash();

  @$internal
  @override
  $ProviderElement<SessionRoomState?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SessionRoomState? create(Ref ref) {
    return currentSessionState(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionRoomState? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionRoomState?>(value),
    );
  }
}

String _$currentSessionStateHash() =>
    r'b6e1f462e3c7fffea06f30a1d11cc9fd467a6844';

/// The connection state of the current session.

@ProviderFor(connectionState)
final connectionStateProvider = ConnectionStateProvider._();

/// The connection state of the current session.

final class ConnectionStateProvider
    extends
        $FunctionalProvider<
          RoomConnectionState,
          RoomConnectionState,
          RoomConnectionState
        >
    with $Provider<RoomConnectionState> {
  /// The connection state of the current session.
  ConnectionStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'connectionStateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$connectionStateHash();

  @$internal
  @override
  $ProviderElement<RoomConnectionState> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RoomConnectionState create(Ref ref) {
    return connectionState(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RoomConnectionState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RoomConnectionState>(value),
    );
  }
}

String _$connectionStateHash() => r'8efbe701958703193973cb95d4d74037b2a963d3';

/// The current session status (waiting, started, ended).

@ProviderFor(sessionStatus)
final sessionStatusProvider = SessionStatusProvider._();

/// The current session status (waiting, started, ended).

final class SessionStatusProvider
    extends $FunctionalProvider<SessionStatus, SessionStatus, SessionStatus>
    with $Provider<SessionStatus> {
  /// The current session status (waiting, started, ended).
  SessionStatusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionStatusProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionStatusHash();

  @$internal
  @override
  $ProviderElement<SessionStatus> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SessionStatus create(Ref ref) {
    return sessionStatus(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionStatus value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionStatus>(value),
    );
  }
}

String _$sessionStatusHash() => r'eecd5c48d330588b6ea87cd188a812a22ecaeee6';

/// The current totem status (none, accepted, passing).

@ProviderFor(totemStatus)
final totemStatusProvider = TotemStatusProvider._();

/// The current totem status (none, accepted, passing).

final class TotemStatusProvider
    extends $FunctionalProvider<TotemStatus, TotemStatus, TotemStatus>
    with $Provider<TotemStatus> {
  /// The current totem status (none, accepted, passing).
  TotemStatusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'totemStatusProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$totemStatusHash();

  @$internal
  @override
  $ProviderElement<TotemStatus> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TotemStatus create(Ref ref) {
    return totemStatus(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TotemStatus value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TotemStatus>(value),
    );
  }
}

String _$totemStatusHash() => r'24ce6085900907638c8887efe82d4f04c690896c';

/// The list of participants in the session.

@ProviderFor(sessionParticipants)
final sessionParticipantsProvider = SessionParticipantsProvider._();

/// The list of participants in the session.

final class SessionParticipantsProvider
    extends
        $FunctionalProvider<
          List<Participant<TrackPublication<Track>>>,
          List<Participant<TrackPublication<Track>>>,
          List<Participant<TrackPublication<Track>>>
        >
    with $Provider<List<Participant<TrackPublication<Track>>>> {
  /// The list of participants in the session.
  SessionParticipantsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionParticipantsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionParticipantsHash();

  @$internal
  @override
  $ProviderElement<List<Participant<TrackPublication<Track>>>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  List<Participant<TrackPublication<Track>>> create(Ref ref) {
    return sessionParticipants(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<Participant<TrackPublication<Track>>> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<List<Participant<TrackPublication<Track>>>>(value),
    );
  }
}

String _$sessionParticipantsHash() =>
    r'7623d8a416b74ad5f94b7b9cdf4845aae914d3d7';

/// Whether it's the current user's turn to speak.

@ProviderFor(isMyTurn)
final isMyTurnProvider = IsMyTurnProvider._();

/// Whether it's the current user's turn to speak.

final class IsMyTurnProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Whether it's the current user's turn to speak.
  IsMyTurnProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'isMyTurnProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$isMyTurnHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return isMyTurn(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$isMyTurnHash() => r'ed38d07c9f1211e9f4b8c2941589bd58d80cc5f3';

/// Whether the current user is next to speak.

@ProviderFor(amNextSpeaker)
final amNextSpeakerProvider = AmNextSpeakerProvider._();

/// Whether the current user is next to speak.

final class AmNextSpeakerProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Whether the current user is next to speak.
  AmNextSpeakerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'amNextSpeakerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$amNextSpeakerHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return amNextSpeaker(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$amNextSpeakerHash() => r'1c84feec9aac91aa8fad50c59b39bbace38bd7eb';
