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
        isAutoDispose: false,
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

String _$sessionScopeHash() => r'efa9c68198a4616b78f64e225a4149d1a9d49e7c';

/// Convenience provider to get the current session notifier.

@ProviderFor(currentSession)
final currentSessionProvider = CurrentSessionProvider._();

/// Convenience provider to get the current session notifier.

final class CurrentSessionProvider
    extends
        $FunctionalProvider<
          SessionController?,
          SessionController?,
          SessionController?
        >
    with $Provider<SessionController?> {
  /// Convenience provider to get the current session notifier.
  CurrentSessionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentSessionProvider',
        isAutoDispose: true,
        dependencies: <ProviderOrFamily>[sessionScopeProvider],
        $allTransitiveDependencies: <ProviderOrFamily>[
          CurrentSessionProvider.$allTransitiveDependencies0,
        ],
      );

  static final $allTransitiveDependencies0 = sessionScopeProvider;

  @override
  String debugGetCreateSourceHash() => _$currentSessionHash();

  @$internal
  @override
  $ProviderElement<SessionController?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SessionController? create(Ref ref) {
    return currentSession(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionController? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionController?>(value),
    );
  }
}

String _$currentSessionHash() => r'c8ae210045352ef458adf80cc2f978b4059535cb';

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
        dependencies: <ProviderOrFamily>[sessionScopeProvider],
        $allTransitiveDependencies: <ProviderOrFamily>[
          CurrentSessionStateProvider.$allTransitiveDependencies0,
        ],
      );

  static final $allTransitiveDependencies0 = sessionScopeProvider;

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
    r'e7a486704dfcdc004ffb74dc9a1df2c0582941f7';

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
        dependencies: <ProviderOrFamily>[currentSessionStateProvider],
        $allTransitiveDependencies: <ProviderOrFamily>[
          ConnectionStateProvider.$allTransitiveDependencies0,
          ConnectionStateProvider.$allTransitiveDependencies1,
        ],
      );

  static final $allTransitiveDependencies0 = currentSessionStateProvider;
  static final $allTransitiveDependencies1 =
      CurrentSessionStateProvider.$allTransitiveDependencies0;

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

String _$connectionStateHash() => r'e7120f187e1bb2c3ff534cf045c17ee3b355e6a3';

/// The high-level lifecycle phase for the current session.

@ProviderFor(sessionPhase)
final sessionPhaseProvider = SessionPhaseProvider._();

/// The high-level lifecycle phase for the current session.

final class SessionPhaseProvider
    extends $FunctionalProvider<SessionPhase, SessionPhase, SessionPhase>
    with $Provider<SessionPhase> {
  /// The high-level lifecycle phase for the current session.
  SessionPhaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionPhaseProvider',
        isAutoDispose: true,
        dependencies: <ProviderOrFamily>[currentSessionStateProvider],
        $allTransitiveDependencies: <ProviderOrFamily>[
          SessionPhaseProvider.$allTransitiveDependencies0,
          SessionPhaseProvider.$allTransitiveDependencies1,
        ],
      );

  static final $allTransitiveDependencies0 = currentSessionStateProvider;
  static final $allTransitiveDependencies1 =
      CurrentSessionStateProvider.$allTransitiveDependencies0;

  @override
  String debugGetCreateSourceHash() => _$sessionPhaseHash();

  @$internal
  @override
  $ProviderElement<SessionPhase> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SessionPhase create(Ref ref) {
    return sessionPhase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionPhase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionPhase>(value),
    );
  }
}

String _$sessionPhaseHash() => r'c4c9982f96bd35dbe119ce4d10c5398ec24a4426';

/// The current session error, if any.

@ProviderFor(sessionError)
final sessionErrorProvider = SessionErrorProvider._();

/// The current session error, if any.

final class SessionErrorProvider
    extends $FunctionalProvider<RoomError?, RoomError?, RoomError?>
    with $Provider<RoomError?> {
  /// The current session error, if any.
  SessionErrorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionErrorProvider',
        isAutoDispose: true,
        dependencies: <ProviderOrFamily>[currentSessionStateProvider],
        $allTransitiveDependencies: <ProviderOrFamily>[
          SessionErrorProvider.$allTransitiveDependencies0,
          SessionErrorProvider.$allTransitiveDependencies1,
        ],
      );

  static final $allTransitiveDependencies0 = currentSessionStateProvider;
  static final $allTransitiveDependencies1 =
      CurrentSessionStateProvider.$allTransitiveDependencies0;

  @override
  String debugGetCreateSourceHash() => _$sessionErrorHash();

  @$internal
  @override
  $ProviderElement<RoomError?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RoomError? create(Ref ref) {
    return sessionError(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RoomError? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RoomError?>(value),
    );
  }
}

String _$sessionErrorHash() => r'5375e24cbec1705f70990ddbcb121016e09701b5';

/// The current session status (waiting, started, ended).

@ProviderFor(roomStatus)
final roomStatusProvider = RoomStatusProvider._();

/// The current session status (waiting, started, ended).

final class RoomStatusProvider
    extends $FunctionalProvider<RoomStatus, RoomStatus, RoomStatus>
    with $Provider<RoomStatus> {
  /// The current session status (waiting, started, ended).
  RoomStatusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'roomStatusProvider',
        isAutoDispose: true,
        dependencies: <ProviderOrFamily>[currentSessionStateProvider],
        $allTransitiveDependencies: <ProviderOrFamily>[
          RoomStatusProvider.$allTransitiveDependencies0,
          RoomStatusProvider.$allTransitiveDependencies1,
        ],
      );

  static final $allTransitiveDependencies0 = currentSessionStateProvider;
  static final $allTransitiveDependencies1 =
      CurrentSessionStateProvider.$allTransitiveDependencies0;

  @override
  String debugGetCreateSourceHash() => _$roomStatusHash();

  @$internal
  @override
  $ProviderElement<RoomStatus> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RoomStatus create(Ref ref) {
    return roomStatus(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RoomStatus value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RoomStatus>(value),
    );
  }
}

String _$roomStatusHash() => r'2d319a778320a8982f1a45cd592f749e43d3919d';

/// The current totem status (none, accepted, passing).

@ProviderFor(turnState)
final turnStateProvider = TurnStateProvider._();

/// The current totem status (none, accepted, passing).

final class TurnStateProvider
    extends $FunctionalProvider<TurnState, TurnState, TurnState>
    with $Provider<TurnState> {
  /// The current totem status (none, accepted, passing).
  TurnStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'turnStateProvider',
        isAutoDispose: true,
        dependencies: <ProviderOrFamily>[currentSessionStateProvider],
        $allTransitiveDependencies: <ProviderOrFamily>[
          TurnStateProvider.$allTransitiveDependencies0,
          TurnStateProvider.$allTransitiveDependencies1,
        ],
      );

  static final $allTransitiveDependencies0 = currentSessionStateProvider;
  static final $allTransitiveDependencies1 =
      CurrentSessionStateProvider.$allTransitiveDependencies0;

  @override
  String debugGetCreateSourceHash() => _$turnStateHash();

  @$internal
  @override
  $ProviderElement<TurnState> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TurnState create(Ref ref) {
    return turnState(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TurnState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TurnState>(value),
    );
  }
}

String _$turnStateHash() => r'2681884a14fea31b39e8e90e59ff498adad7720e';

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
        dependencies: <ProviderOrFamily>[currentSessionStateProvider],
        $allTransitiveDependencies: <ProviderOrFamily>[
          SessionParticipantsProvider.$allTransitiveDependencies0,
          SessionParticipantsProvider.$allTransitiveDependencies1,
        ],
      );

  static final $allTransitiveDependencies0 = currentSessionStateProvider;
  static final $allTransitiveDependencies1 =
      CurrentSessionStateProvider.$allTransitiveDependencies0;

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
    r'10990e4bffa481e16748e63e0e77394db35a87cd';

/// Current session error as a LiveKitError, if applicable.

@ProviderFor(sessionLivekitError)
final sessionLivekitErrorProvider = SessionLivekitErrorProvider._();

/// Current session error as a LiveKitError, if applicable.

final class SessionLivekitErrorProvider
    extends
        $FunctionalProvider<
          LiveKitException?,
          LiveKitException?,
          LiveKitException?
        >
    with $Provider<LiveKitException?> {
  /// Current session error as a LiveKitError, if applicable.
  SessionLivekitErrorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionLivekitErrorProvider',
        isAutoDispose: true,
        dependencies: <ProviderOrFamily>[sessionErrorProvider],
        $allTransitiveDependencies: <ProviderOrFamily>[
          SessionLivekitErrorProvider.$allTransitiveDependencies0,
          SessionLivekitErrorProvider.$allTransitiveDependencies1,
          SessionLivekitErrorProvider.$allTransitiveDependencies2,
        ],
      );

  static final $allTransitiveDependencies0 = sessionErrorProvider;
  static final $allTransitiveDependencies1 =
      SessionErrorProvider.$allTransitiveDependencies0;
  static final $allTransitiveDependencies2 =
      SessionErrorProvider.$allTransitiveDependencies1;

  @override
  String debugGetCreateSourceHash() => _$sessionLivekitErrorHash();

  @$internal
  @override
  $ProviderElement<LiveKitException?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  LiveKitException? create(Ref ref) {
    return sessionLivekitError(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LiveKitException? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LiveKitException?>(value),
    );
  }
}

String _$sessionLivekitErrorHash() =>
    r'db1f3228dbf9496c005a98d72ee1a2f3602dc3da';

/// Current session error as a DisconnectionError, if applicable.

@ProviderFor(disconnectionReason)
final disconnectionReasonProvider = DisconnectionReasonProvider._();

/// Current session error as a DisconnectionError, if applicable.

final class DisconnectionReasonProvider
    extends
        $FunctionalProvider<
          DisconnectReason?,
          DisconnectReason?,
          DisconnectReason?
        >
    with $Provider<DisconnectReason?> {
  /// Current session error as a DisconnectionError, if applicable.
  DisconnectionReasonProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'disconnectionReasonProvider',
        isAutoDispose: true,
        dependencies: <ProviderOrFamily>[sessionErrorProvider],
        $allTransitiveDependencies: <ProviderOrFamily>[
          DisconnectionReasonProvider.$allTransitiveDependencies0,
          DisconnectionReasonProvider.$allTransitiveDependencies1,
          DisconnectionReasonProvider.$allTransitiveDependencies2,
        ],
      );

  static final $allTransitiveDependencies0 = sessionErrorProvider;
  static final $allTransitiveDependencies1 =
      SessionErrorProvider.$allTransitiveDependencies0;
  static final $allTransitiveDependencies2 =
      SessionErrorProvider.$allTransitiveDependencies1;

  @override
  String debugGetCreateSourceHash() => _$disconnectionReasonHash();

  @$internal
  @override
  $ProviderElement<DisconnectReason?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DisconnectReason? create(Ref ref) {
    return disconnectionReason(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DisconnectReason? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DisconnectReason?>(value),
    );
  }
}

String _$disconnectionReasonHash() =>
    r'7101bc468c99e2f90e436d6c68716a3fee19cdcb';

/// Whether the keeper is currently disconnected.

@ProviderFor(hasKeeperDisconnected)
final hasKeeperDisconnectedProvider = HasKeeperDisconnectedProvider._();

/// Whether the keeper is currently disconnected.

final class HasKeeperDisconnectedProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Whether the keeper is currently disconnected.
  HasKeeperDisconnectedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'hasKeeperDisconnectedProvider',
        isAutoDispose: true,
        dependencies: <ProviderOrFamily>[currentSessionStateProvider],
        $allTransitiveDependencies: <ProviderOrFamily>[
          HasKeeperDisconnectedProvider.$allTransitiveDependencies0,
          HasKeeperDisconnectedProvider.$allTransitiveDependencies1,
        ],
      );

  static final $allTransitiveDependencies0 = currentSessionStateProvider;
  static final $allTransitiveDependencies1 =
      CurrentSessionStateProvider.$allTransitiveDependencies0;

  @override
  String debugGetCreateSourceHash() => _$hasKeeperDisconnectedHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return hasKeeperDisconnected(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$hasKeeperDisconnectedHash() =>
    r'c20d31da8e1761c56e8c9468346a7d5673aaa22b';

/// All chat messages for the current session.

@ProviderFor(sessionMessages)
final sessionMessagesProvider = SessionMessagesProvider._();

/// All chat messages for the current session.

final class SessionMessagesProvider
    extends
        $FunctionalProvider<
          List<SessionChatMessage>,
          List<SessionChatMessage>,
          List<SessionChatMessage>
        >
    with $Provider<List<SessionChatMessage>> {
  /// All chat messages for the current session.
  SessionMessagesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionMessagesProvider',
        isAutoDispose: true,
        dependencies: <ProviderOrFamily>[currentSessionStateProvider],
        $allTransitiveDependencies: <ProviderOrFamily>[
          SessionMessagesProvider.$allTransitiveDependencies0,
          SessionMessagesProvider.$allTransitiveDependencies1,
        ],
      );

  static final $allTransitiveDependencies0 = currentSessionStateProvider;
  static final $allTransitiveDependencies1 =
      CurrentSessionStateProvider.$allTransitiveDependencies0;

  @override
  String debugGetCreateSourceHash() => _$sessionMessagesHash();

  @$internal
  @override
  $ProviderElement<List<SessionChatMessage>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  List<SessionChatMessage> create(Ref ref) {
    return sessionMessages(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<SessionChatMessage> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<SessionChatMessage>>(value),
    );
  }
}

String _$sessionMessagesHash() => r'a1a4a2f82da8c165d00852e6afcd1421da168f3e';

/// Last chat message if available.

@ProviderFor(lastSessionMessage)
final lastSessionMessageProvider = LastSessionMessageProvider._();

/// Last chat message if available.

final class LastSessionMessageProvider
    extends
        $FunctionalProvider<
          SessionChatMessage?,
          SessionChatMessage?,
          SessionChatMessage?
        >
    with $Provider<SessionChatMessage?> {
  /// Last chat message if available.
  LastSessionMessageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'lastSessionMessageProvider',
        isAutoDispose: true,
        dependencies: <ProviderOrFamily>[sessionMessagesProvider],
        $allTransitiveDependencies: <ProviderOrFamily>[
          LastSessionMessageProvider.$allTransitiveDependencies0,
          LastSessionMessageProvider.$allTransitiveDependencies1,
          LastSessionMessageProvider.$allTransitiveDependencies2,
        ],
      );

  static final $allTransitiveDependencies0 = sessionMessagesProvider;
  static final $allTransitiveDependencies1 =
      SessionMessagesProvider.$allTransitiveDependencies0;
  static final $allTransitiveDependencies2 =
      SessionMessagesProvider.$allTransitiveDependencies1;

  @override
  String debugGetCreateSourceHash() => _$lastSessionMessageHash();

  @$internal
  @override
  $ProviderElement<SessionChatMessage?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SessionChatMessage? create(Ref ref) {
    return lastSessionMessage(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionChatMessage? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionChatMessage?>(value),
    );
  }
}

String _$lastSessionMessageHash() =>
    r'2890e31c29fe9873216acebb21ccb63c7f5b38a4';

/// Optional round message sent by the keeper for the active round.

@ProviderFor(roundMessage)
final roundMessageProvider = RoundMessageProvider._();

/// Optional round message sent by the keeper for the active round.

final class RoundMessageProvider
    extends $FunctionalProvider<String?, String?, String?>
    with $Provider<String?> {
  /// Optional round message sent by the keeper for the active round.
  RoundMessageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'roundMessageProvider',
        isAutoDispose: true,
        dependencies: <ProviderOrFamily>[currentSessionStateProvider],
        $allTransitiveDependencies: <ProviderOrFamily>[
          RoundMessageProvider.$allTransitiveDependencies0,
          RoundMessageProvider.$allTransitiveDependencies1,
        ],
      );

  static final $allTransitiveDependencies0 = currentSessionStateProvider;
  static final $allTransitiveDependencies1 =
      CurrentSessionStateProvider.$allTransitiveDependencies0;

  @override
  String debugGetCreateSourceHash() => _$roundMessageHash();

  @$internal
  @override
  $ProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String? create(Ref ref) {
    return roundMessage(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$roundMessageHash() => r'abde7123ab37cc267d1221fbdc1a713e8142aa57';

/// Whether the keeper participant is currently present in the room.

@ProviderFor(hasKeeper)
final hasKeeperProvider = HasKeeperProvider._();

/// Whether the keeper participant is currently present in the room.

final class HasKeeperProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Whether the keeper participant is currently present in the room.
  HasKeeperProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'hasKeeperProvider',
        isAutoDispose: true,
        dependencies: <ProviderOrFamily>[currentSessionStateProvider],
        $allTransitiveDependencies: <ProviderOrFamily>[
          HasKeeperProvider.$allTransitiveDependencies0,
          HasKeeperProvider.$allTransitiveDependencies1,
        ],
      );

  static final $allTransitiveDependencies0 = currentSessionStateProvider;
  static final $allTransitiveDependencies1 =
      CurrentSessionStateProvider.$allTransitiveDependencies0;

  @override
  String debugGetCreateSourceHash() => _$hasKeeperHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return hasKeeper(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$hasKeeperHash() => r'f8cf3469edf5bb396aad98c56a1a023178f0fd25';

/// Participant currently featured in the room layout.

@ProviderFor(featuredParticipant)
final featuredParticipantProvider = FeaturedParticipantProvider._();

/// Participant currently featured in the room layout.

final class FeaturedParticipantProvider
    extends
        $FunctionalProvider<
          Participant<TrackPublication<Track>>?,
          Participant<TrackPublication<Track>>?,
          Participant<TrackPublication<Track>>?
        >
    with $Provider<Participant<TrackPublication<Track>>?> {
  /// Participant currently featured in the room layout.
  FeaturedParticipantProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'featuredParticipantProvider',
        isAutoDispose: true,
        dependencies: <ProviderOrFamily>[currentSessionStateProvider],
        $allTransitiveDependencies: <ProviderOrFamily>[
          FeaturedParticipantProvider.$allTransitiveDependencies0,
          FeaturedParticipantProvider.$allTransitiveDependencies1,
        ],
      );

  static final $allTransitiveDependencies0 = currentSessionStateProvider;
  static final $allTransitiveDependencies1 =
      CurrentSessionStateProvider.$allTransitiveDependencies0;

  @override
  String debugGetCreateSourceHash() => _$featuredParticipantHash();

  @$internal
  @override
  $ProviderElement<Participant<TrackPublication<Track>>?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  Participant<TrackPublication<Track>>? create(Ref ref) {
    return featuredParticipant(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Participant<TrackPublication<Track>>? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<Participant<TrackPublication<Track>>?>(value),
    );
  }
}

String _$featuredParticipantHash() =>
    r'37c1fd41686ef04c3977f8c2c0bcf075635687dd';

/// Participant expected to speak next.

@ProviderFor(speakingNextParticipant)
final speakingNextParticipantProvider = SpeakingNextParticipantProvider._();

/// Participant expected to speak next.

final class SpeakingNextParticipantProvider
    extends
        $FunctionalProvider<
          Participant<TrackPublication<Track>>?,
          Participant<TrackPublication<Track>>?,
          Participant<TrackPublication<Track>>?
        >
    with $Provider<Participant<TrackPublication<Track>>?> {
  /// Participant expected to speak next.
  SpeakingNextParticipantProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'speakingNextParticipantProvider',
        isAutoDispose: true,
        dependencies: <ProviderOrFamily>[currentSessionStateProvider],
        $allTransitiveDependencies: <ProviderOrFamily>[
          SpeakingNextParticipantProvider.$allTransitiveDependencies0,
          SpeakingNextParticipantProvider.$allTransitiveDependencies1,
        ],
      );

  static final $allTransitiveDependencies0 = currentSessionStateProvider;
  static final $allTransitiveDependencies1 =
      CurrentSessionStateProvider.$allTransitiveDependencies0;

  @override
  String debugGetCreateSourceHash() => _$speakingNextParticipantHash();

  @$internal
  @override
  $ProviderElement<Participant<TrackPublication<Track>>?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  Participant<TrackPublication<Track>>? create(Ref ref) {
    return speakingNextParticipant(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Participant<TrackPublication<Track>>? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<Participant<TrackPublication<Track>>?>(value),
    );
  }
}

String _$speakingNextParticipantHash() =>
    r'aedb4a4c2543eebe2de4ba45925a7e45857d7319';

/// Active session event payload.

@ProviderFor(currentSessionEvent)
final currentSessionEventProvider = CurrentSessionEventProvider._();

/// Active session event payload.

final class CurrentSessionEventProvider
    extends
        $FunctionalProvider<
          SessionDetailSchema?,
          SessionDetailSchema?,
          SessionDetailSchema?
        >
    with $Provider<SessionDetailSchema?> {
  /// Active session event payload.
  CurrentSessionEventProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentSessionEventProvider',
        isAutoDispose: true,
        dependencies: <ProviderOrFamily>[currentSessionProvider],
        $allTransitiveDependencies: <ProviderOrFamily>[
          CurrentSessionEventProvider.$allTransitiveDependencies0,
          CurrentSessionEventProvider.$allTransitiveDependencies1,
        ],
      );

  static final $allTransitiveDependencies0 = currentSessionProvider;
  static final $allTransitiveDependencies1 =
      CurrentSessionProvider.$allTransitiveDependencies0;

  @override
  String debugGetCreateSourceHash() => _$currentSessionEventHash();

  @$internal
  @override
  $ProviderElement<SessionDetailSchema?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SessionDetailSchema? create(Ref ref) {
    return currentSessionEvent(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionDetailSchema? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionDetailSchema?>(value),
    );
  }
}

String _$currentSessionEventHash() =>
    r'3eb0b74e1d2b4d19a926d97a972a4fb2e0f9a13e';

/// Whether the signed-in user is keeper for the current session.

@ProviderFor(isCurrentUserKeeper)
final isCurrentUserKeeperProvider = IsCurrentUserKeeperProvider._();

/// Whether the signed-in user is keeper for the current session.

final class IsCurrentUserKeeperProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Whether the signed-in user is keeper for the current session.
  IsCurrentUserKeeperProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'isCurrentUserKeeperProvider',
        isAutoDispose: true,
        dependencies: <ProviderOrFamily>[currentSessionProvider],
        $allTransitiveDependencies: <ProviderOrFamily>[
          IsCurrentUserKeeperProvider.$allTransitiveDependencies0,
          IsCurrentUserKeeperProvider.$allTransitiveDependencies1,
        ],
      );

  static final $allTransitiveDependencies0 = currentSessionProvider;
  static final $allTransitiveDependencies1 =
      CurrentSessionProvider.$allTransitiveDependencies0;

  @override
  String debugGetCreateSourceHash() => _$isCurrentUserKeeperHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return isCurrentUserKeeper(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$isCurrentUserKeeperHash() =>
    r'd54f8f6fa174808caf5f6b841000b486cec37169';

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
        dependencies: <ProviderOrFamily>[
          currentSessionProvider,
          currentSessionStateProvider,
        ],
        $allTransitiveDependencies: <ProviderOrFamily>[
          IsMyTurnProvider.$allTransitiveDependencies0,
          IsMyTurnProvider.$allTransitiveDependencies1,
          IsMyTurnProvider.$allTransitiveDependencies2,
        ],
      );

  static final $allTransitiveDependencies0 = currentSessionProvider;
  static final $allTransitiveDependencies1 =
      CurrentSessionProvider.$allTransitiveDependencies0;
  static final $allTransitiveDependencies2 = currentSessionStateProvider;

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

String _$isMyTurnHash() => r'503507e6413231eeca020a5b684a3ab8484dc5b8';

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
        dependencies: <ProviderOrFamily>[
          currentSessionProvider,
          currentSessionStateProvider,
        ],
        $allTransitiveDependencies: <ProviderOrFamily>[
          AmNextSpeakerProvider.$allTransitiveDependencies0,
          AmNextSpeakerProvider.$allTransitiveDependencies1,
          AmNextSpeakerProvider.$allTransitiveDependencies2,
        ],
      );

  static final $allTransitiveDependencies0 = currentSessionProvider;
  static final $allTransitiveDependencies1 =
      CurrentSessionProvider.$allTransitiveDependencies0;
  static final $allTransitiveDependencies2 = currentSessionStateProvider;

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

String _$amNextSpeakerHash() => r'fac9121165d1dc018fb2fc96eadf53038b0a264b';
