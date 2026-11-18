import 'dart:async';
import 'dart:collection';

import 'package:checks/checks.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart' as sdk;
import 'package:mocktail/mocktail.dart';
import 'package:totem_core/features/sessions/media/livekit_session_transport.dart';
import 'package:totem_core/features/sessions/transport/session_transport.dart';
import '../livekit_mocks.dart';

class _Room extends FakeRoom {
  _Room(super.participant);
  final transportEvents = sdk.EventsEmitter<sdk.RoomEvent>();
  int connections = 0;
  int disposals = 0;
  sdk.ConnectOptions? connectedOptions;
  sdk.LiveKitException? failure;
  final remotes = <String, sdk.RemoteParticipant>{};
  @override
  UnmodifiableMapView<String, sdk.RemoteParticipant> get remoteParticipants =>
      UnmodifiableMapView(remotes);
  @override
  sdk.ConnectionState connectionState = sdk.ConnectionState.connected;
  @override
  sdk.EventsListener<sdk.RoomEvent> createListener({
    bool synchronized = false,
  }) => sdk.EventsListener(transportEvents, synchronized: synchronized);
  @override
  Future<void> prepareConnection(String url, String? token) async {}
  @override
  Future<void> connect(
    String url,
    String token, {
    sdk.ConnectOptions? connectOptions,
    sdk.FastConnectOptions? fastConnectOptions,
    sdk.RoomOptions? roomOptions,
  }) async {
    connections++;
    connectedOptions = connectOptions;
    if (failure case final sdk.LiveKitException error) throw error;
    connectionState = sdk.ConnectionState.connected;
    transportEvents.emit(sdk.RoomConnectedEvent(room: this, metadata: null));
  }

  @override
  Future<void> disconnect() async {
    connectionState = sdk.ConnectionState.disconnected;
    transportEvents.emit(
      sdk.RoomDisconnectedEvent(reason: sdk.DisconnectReason.clientInitiated),
    );
  }

  @override
  Future<bool> dispose() async {
    disposals++;
    return true;
  }
}

class _Remote extends MockRemoteParticipant {
  _Remote(this.publications, [String identity = 'remote'])
    : super(identity, 'Remote');
  final List<sdk.RemoteTrackPublication<sdk.RemoteTrack>> publications;
  @override
  List<sdk.RemoteTrackPublication<sdk.RemoteTrack>> getTrackPublications() =>
      publications;
}

void main() {
  test(
    'revocation during a pending subscribe eventually removes media',
    () async {
      final publication = MockRemoteTrackPublication<sdk.RemoteTrack>();
      final pending = Completer<void>();
      var subscribed = false;
      when(() => publication.subscribed).thenAnswer((_) => subscribed);
      when(publication.subscribe).thenAnswer((_) async {
        await pending.future;
        subscribed = true;
      });
      when(publication.unsubscribe).thenAnswer((_) async {
        subscribed = false;
      });
      final room = _Room(MockLocalParticipant())
        ..remotes['remote'] = _Remote([publication]);
      final transport = LiveKitSessionTransport(
        room: room,
        cameraOptions: const sdk.CameraCaptureOptions(),
      );
      try {
        transport.setIncomingMediaParticipants({'remote'});
        final initial = transport.subscribeToExistingMedia();
        transport.setIncomingMediaParticipants({});
        await pumpEventQueue();
        pending.complete();
        await initial;
        await pumpEventQueue();
        check(subscribed).isFalse();
      } finally {
        if (!pending.isCompleted) pending.complete();
        await transport.dispose();
        await room.transportEvents.dispose();
      }
    },
  );

  test(
    'reconnects deduplicate pending work and disconnect invalidates it',
    () async {
      final publication = MockRemoteTrackPublication<sdk.RemoteTrack>();
      final pending = Completer<void>();
      var attempts = 0;
      when(publication.subscribe).thenAnswer((_) {
        attempts++;
        return attempts == 1 ? pending.future : Future.value();
      });
      final room = _Room(MockLocalParticipant())
        ..remotes['remote'] = _Remote([publication]);
      final transport = LiveKitSessionTransport(
        room: room,
        cameraOptions: const sdk.CameraCaptureOptions(),
      );
      try {
        transport.setIncomingMediaParticipants({'remote'});
        final initial = transport.subscribeToExistingMedia();
        room.transportEvents.emit(const sdk.RoomReconnectedEvent());
        room.transportEvents.emit(const sdk.RoomReconnectedEvent());
        await pumpEventQueue();
        check(attempts).equals(1);
        await transport.disconnect();
        await pumpEventQueue();
        pending.complete();
        await initial;
        await transport.connect('url', 'token');
        await transport.subscribeToExistingMedia();
        check(attempts).equals(2);
      } finally {
        if (!pending.isCompleted) pending.complete();
        await transport.dispose();
        await room.transportEvents.dispose();
      }
    },
  );

  test('participant departure during subscribe removes late media', () async {
    final publication = MockRemoteTrackPublication<sdk.RemoteTrack>();
    final pending = Completer<void>();
    var subscribed = false;
    when(() => publication.subscribed).thenAnswer((_) => subscribed);
    when(publication.subscribe).thenAnswer((_) async {
      await pending.future;
      subscribed = true;
    });
    when(publication.unsubscribe).thenAnswer((_) async {
      subscribed = false;
    });
    final remote = _Remote([publication]);
    final room = _Room(MockLocalParticipant())..remotes['remote'] = remote;
    final transport = LiveKitSessionTransport(
      room: room,
      cameraOptions: const sdk.CameraCaptureOptions(),
    );
    try {
      transport.setIncomingMediaParticipants({'remote'});
      final initial = transport.subscribeToExistingMedia();
      room.remotes.remove('remote');
      room.transportEvents.emit(
        sdk.ParticipantDisconnectedEvent(participant: remote),
      );
      await pumpEventQueue();
      pending.complete();
      await initial;
      await pumpEventQueue();
      check(subscribed).isFalse();
    } finally {
      if (!pending.isCompleted) pending.complete();
      await transport.dispose();
      await room.transportEvents.dispose();
    }
  });

  test(
    'late unauthorized subscribed event waits for pending subscribe cleanup',
    () async {
      final publication = MockRemoteTrackPublication<sdk.RemoteTrack>();
      final pending = Completer<void>();
      var subscribed = false;
      var unsubscribeCalls = 0;
      when(() => publication.subscribed).thenAnswer((_) => subscribed);
      when(publication.subscribe).thenAnswer((_) async {
        await pending.future;
        subscribed = true;
      });
      when(publication.unsubscribe).thenAnswer((_) async {
        unsubscribeCalls++;
        subscribed = false;
      });
      final remote = _Remote([publication]);
      final room = _Room(MockLocalParticipant())..remotes['remote'] = remote;
      final transport = LiveKitSessionTransport(
        room: room,
        cameraOptions: const sdk.CameraCaptureOptions(),
      );
      try {
        transport.setIncomingMediaParticipants({'remote'});
        final initial = transport.subscribeToExistingMedia();
        transport.setIncomingMediaParticipants({});
        room.transportEvents.emit(
          sdk.TrackSubscribedEvent(
            participant: remote,
            publication: publication,
            track: MockRemoteVideoTrack(),
          ),
        );
        await pumpEventQueue();
        check(unsubscribeCalls).equals(0);
        pending.complete();
        await initial;
        await pumpEventQueue();
        check(subscribed).isFalse();
        check(unsubscribeCalls).equals(1);
      } finally {
        if (!pending.isCompleted) pending.complete();
        await transport.dispose();
        await room.transportEvents.dispose();
      }
    },
  );

  test('a delayed unsubscribe cannot undo a newer admission', () async {
    final publication = MockRemoteTrackPublication<sdk.RemoteTrack>();
    final pending = Completer<void>();
    var subscribed = false;
    var subscribeCalls = 0;
    when(() => publication.subscribed).thenAnswer((_) => subscribed);
    when(publication.subscribe).thenAnswer((_) async {
      subscribeCalls++;
      subscribed = true;
    });
    when(publication.unsubscribe).thenAnswer((_) async {
      await pending.future;
      subscribed = false;
    });
    final room = _Room(MockLocalParticipant())
      ..remotes['remote'] = _Remote([publication]);
    final transport = LiveKitSessionTransport(
      room: room,
      cameraOptions: const sdk.CameraCaptureOptions(),
    );
    try {
      transport.setIncomingMediaParticipants({'remote'});
      await transport.subscribeToExistingMedia();
      transport.setIncomingMediaParticipants({});
      await pumpEventQueue();
      transport.setIncomingMediaParticipants({'remote'});
      await pumpEventQueue();
      check(subscribeCalls).equals(1);
      pending.complete();
      await pumpEventQueue();
      check(subscribed).isTrue();
    } finally {
      if (!pending.isCompleted) pending.complete();
      await transport.dispose();
      await room.transportEvents.dispose();
    }
  });

  test(
    'a replaced publication is reconciled while its predecessor is pending',
    () async {
      final original = MockRemoteTrackPublication<sdk.RemoteTrack>();
      final replacement = MockRemoteTrackPublication<sdk.RemoteTrack>();
      final pending = Completer<void>();
      var originalSubscribed = false;
      var replacementSubscribed = false;
      when(() => original.subscribed).thenAnswer((_) => originalSubscribed);
      when(
        () => replacement.subscribed,
      ).thenAnswer((_) => replacementSubscribed);
      when(original.subscribe).thenAnswer((_) async {
        await pending.future;
        originalSubscribed = true;
      });
      when(original.unsubscribe).thenAnswer((_) async {
        originalSubscribed = false;
      });
      when(replacement.subscribe).thenAnswer((_) async {
        replacementSubscribed = true;
      });
      final remote = _Remote([original]);
      final room = _Room(MockLocalParticipant())..remotes['remote'] = remote;
      final transport = LiveKitSessionTransport(
        room: room,
        cameraOptions: const sdk.CameraCaptureOptions(),
      );
      try {
        transport.setIncomingMediaParticipants({'remote'});
        final initial = transport.subscribeToExistingMedia();
        remote.publications
          ..clear()
          ..add(replacement);
        room.transportEvents.emit(const sdk.RoomReconnectedEvent());
        await pumpEventQueue();
        pending.complete();
        await initial;
        await pumpEventQueue();
        check(originalSubscribed).isFalse();
        check(replacementSubscribed).isTrue();
      } finally {
        if (!pending.isCompleted) pending.complete();
        await transport.dispose();
        await room.transportEvents.dispose();
      }
    },
  );

  test(
    'full reconnect serializes replacement publications with the same SID',
    () async {
      final original = MockRemoteTrackPublication<sdk.RemoteTrack>();
      final replacement = MockRemoteTrackPublication<sdk.RemoteTrack>();
      final subscribePending = Completer<void>();
      final unsubscribePending = Completer<void>();
      final operations = <String>[];
      var originalSubscribed = false;
      var replacementSubscribed = false;
      when(() => original.sid).thenReturn('same-track');
      when(() => replacement.sid).thenReturn('same-track');
      when(() => original.subscribed).thenAnswer((_) => originalSubscribed);
      when(
        () => replacement.subscribed,
      ).thenAnswer((_) => replacementSubscribed);
      when(original.subscribe).thenAnswer((_) async {
        operations.add('original subscribe');
        await subscribePending.future;
        originalSubscribed = true;
      });
      when(original.unsubscribe).thenAnswer((_) async {
        operations.add('original unsubscribe');
        await unsubscribePending.future;
        originalSubscribed = false;
        replacementSubscribed = false;
      });
      when(replacement.subscribe).thenAnswer((_) async {
        operations.add('replacement subscribe');
        replacementSubscribed = true;
      });
      when(replacement.unsubscribe).thenAnswer((_) async {
        replacementSubscribed = false;
      });
      final originalRemote = _Remote([original]);
      final room = _Room(MockLocalParticipant())
        ..remotes['remote'] = originalRemote;
      final transport = LiveKitSessionTransport(
        room: room,
        cameraOptions: const sdk.CameraCaptureOptions(),
      );
      try {
        transport.setIncomingMediaParticipants({'remote'});
        final initial = transport.subscribeToExistingMedia();
        room.transportEvents.emit(const sdk.RoomReconnectingEvent());
        room.remotes['remote'] = _Remote([replacement]);
        room.transportEvents.emit(const sdk.RoomReconnectedEvent());
        await pumpEventQueue();
        check(operations).deepEquals(['original subscribe']);
        subscribePending.complete();
        await pumpEventQueue();
        check(
          operations,
        ).deepEquals(['original subscribe', 'original unsubscribe']);
        check(originalSubscribed).isTrue();
        check(replacementSubscribed).isFalse();
        unsubscribePending.complete();
        await initial;
        await pumpEventQueue();
        check(operations).deepEquals([
          'original subscribe',
          'original unsubscribe',
          'replacement subscribe',
        ]);
        check(originalSubscribed).isFalse();
        check(replacementSubscribed).isTrue();
        room.transportEvents.emit(
          sdk.TrackSubscribedEvent(
            participant: originalRemote,
            publication: original,
            track: MockRemoteVideoTrack(),
          ),
        );
        await pumpEventQueue();
        check(operations).deepEquals([
          'original subscribe',
          'original unsubscribe',
          'replacement subscribe',
        ]);
        check(replacementSubscribed).isTrue();
      } finally {
        if (!subscribePending.isCompleted) subscribePending.complete();
        if (!unsubscribePending.isCompleted) unsubscribePending.complete();
        await pumpEventQueue();
        await transport.dispose();
        await room.transportEvents.dispose();
      }
    },
  );

  test(
    'full reconnect replacements keep only the current publication cached',
    () async {
      final subscribed = <bool>[];
      final subscribeCalls = <int>[];
      MockRemoteTrackPublication<sdk.RemoteTrack> publication() {
        final index = subscribed.length;
        subscribed.add(false);
        subscribeCalls.add(0);
        final track = MockRemoteTrackPublication<sdk.RemoteTrack>();
        when(() => track.sid).thenReturn('same-track');
        when(() => track.subscribed).thenAnswer((_) => subscribed[index]);
        when(track.subscribe).thenAnswer((_) async {
          subscribeCalls[index]++;
          subscribed[index] = true;
        });
        when(track.unsubscribe).thenAnswer((_) async {
          subscribed[index] = false;
        });
        return track;
      }

      final room = _Room(MockLocalParticipant())
        ..remotes['remote'] = _Remote([publication()]);
      final transport = LiveKitSessionTransport(
        room: room,
        cameraOptions: const sdk.CameraCaptureOptions(),
      );
      try {
        transport.setIncomingMediaParticipants({'remote'});
        await transport.subscribeToExistingMedia();
        check(transport.cachedRemotePublicationCount).equals(1);
        for (var i = 0; i < 10; i++) {
          room.transportEvents.emit(const sdk.RoomReconnectingEvent());
          await pumpEventQueue();
          room.remotes['remote'] = _Remote([publication()]);
          room.transportEvents.emit(const sdk.RoomReconnectedEvent());
          await pumpEventQueue();
          check(transport.cachedRemotePublicationCount).equals(1);
          check(subscribed.last).isTrue();
          check(subscribeCalls).deepEquals(List.filled(i + 2, 1));
          room.transportEvents.emit(const sdk.RoomReconnectedEvent());
          await pumpEventQueue();
          check(subscribeCalls).deepEquals(List.filled(i + 2, 1));
          check(transport.cachedRemotePublicationCount).equals(1);
        }
        await transport.dispose();
        check(transport.cachedRemotePublicationCount).equals(0);
      } finally {
        await transport.dispose();
        await room.transportEvents.dispose();
      }
    },
  );

  test('failed revocation retries without blocking admitted media', () {
    fakeAsync((clock) {
      final revoked = MockRemoteTrackPublication<sdk.RemoteTrack>();
      final keeper = MockRemoteTrackPublication<sdk.RemoteTrack>();
      var revokedSubscribed = false;
      var keeperSubscribed = false;
      var unsubscribeAttempts = 0;
      var failThrough = 3;
      when(() => revoked.subscribed).thenAnswer((_) => revokedSubscribed);
      when(() => keeper.subscribed).thenAnswer((_) => keeperSubscribed);
      when(revoked.subscribe).thenAnswer((_) async {
        revokedSubscribed = true;
      });
      when(keeper.subscribe).thenAnswer((_) async {
        keeperSubscribed = true;
      });
      when(revoked.unsubscribe).thenAnswer((_) async {
        if (++unsubscribeAttempts <= failThrough) {
          throw StateError('temporary failure');
        }
        revokedSubscribed = false;
      });
      when(keeper.unsubscribe).thenAnswer((_) async {
        keeperSubscribed = false;
      });
      final room = _Room(MockLocalParticipant())
        ..remotes.addAll({
          'revoked': _Remote([revoked], 'revoked'),
          'keeper': _Remote([keeper], 'keeper'),
        });
      final transport = LiveKitSessionTransport(
        room: room,
        cameraOptions: const sdk.CameraCaptureOptions(),
      );
      final errors = <Object>[];
      final listener = transport.events.listen((_) {}, onError: errors.add);
      try {
        transport.setIncomingMediaParticipants({'revoked', 'keeper'});
        unawaited(transport.subscribeToExistingMedia());
        clock.flushMicrotasks();
        transport.setIncomingMediaParticipants({'keeper'});
        clock.flushMicrotasks();
        check(keeperSubscribed).isTrue();
        check(unsubscribeAttempts).equals(2);
        check(revokedSubscribed).isTrue();
        clock
          ..elapse(const Duration(seconds: 1))
          ..flushMicrotasks();
        check(unsubscribeAttempts).equals(4);
        check(revokedSubscribed).isFalse();
        check(keeperSubscribed).isTrue();

        transport.setIncomingMediaParticipants({'revoked', 'keeper'});
        clock.flushMicrotasks();
        check(revokedSubscribed).isTrue();
        failThrough = unsubscribeAttempts + 10;
        transport.setIncomingMediaParticipants({'keeper'});
        clock.flushMicrotasks();
        unawaited(transport.dispose());
        clock.flushMicrotasks();
        final attemptsAfterDispose = unsubscribeAttempts;
        clock
          ..elapse(const Duration(minutes: 2))
          ..flushMicrotasks();
        check(unsubscribeAttempts).equals(attemptsAfterDispose);
      } finally {
        unawaited(listener.cancel());
        unawaited(transport.dispose());
        unawaited(room.transportEvents.dispose());
        clock.flushMicrotasks();
      }
    });
  });

  test(
    'unchanged roster preserves existing subscriptions without SDK cycles',
    () async {
      final alreadySubscribed = MockRemoteTrackPublication<sdk.RemoteTrack>();
      final newlySubscribed = MockRemoteTrackPublication<sdk.RemoteTrack>();
      when(() => alreadySubscribed.subscribed).thenReturn(true);
      when(newlySubscribed.subscribe).thenAnswer((_) async {});
      final room = _Room(MockLocalParticipant())
        ..remotes['remote'] = _Remote([alreadySubscribed, newlySubscribed]);
      final transport = LiveKitSessionTransport(
        room: room,
        cameraOptions: const sdk.CameraCaptureOptions(),
      );
      try {
        transport.setIncomingMediaParticipants({'remote'});
        await transport.subscribeToExistingMedia();
        verifyNever(alreadySubscribed.subscribe);
        verify(newlySubscribed.subscribe).called(1);
        transport.setIncomingMediaParticipants({'remote'});
        await transport.subscribeToExistingMedia();
        await pumpEventQueue();
        verifyNever(alreadySubscribed.subscribe);
        verifyNever(newlySubscribed.subscribe);
        verifyNever(alreadySubscribed.unsubscribe);
        verifyNever(newlySubscribed.unsubscribe);
      } finally {
        await transport.dispose();
        await room.transportEvents.dispose();
      }
    },
  );

  test(
    'resume reconciles missed permission denial without retrying unchanged media',
    () async {
      final denied = MockRemoteTrackPublication<sdk.RemoteTrack>();
      final unchanged = MockRemoteTrackPublication<sdk.RemoteTrack>();
      var allowed = true;
      when(() => denied.subscriptionAllowed).thenAnswer((_) => allowed);
      when(denied.subscribe).thenAnswer((_) async {});
      when(unchanged.subscribe).thenAnswer((_) async {});
      final remote = _Remote([denied, unchanged]);
      final room = _Room(MockLocalParticipant())..remotes['remote'] = remote;
      final transport = LiveKitSessionTransport(
        room: room,
        cameraOptions: const sdk.CameraCaptureOptions(),
      );
      final states = <TransportConnectionChanged>[];
      final listener = transport.events
          .where((event) => event is TransportConnectionChanged)
          .cast<TransportConnectionChanged>()
          .listen(states.add);
      try {
        transport.setIncomingMediaParticipants({'remote'});
        await transport.subscribeToExistingMedia();
        verify(denied.subscribe).called(1);
        verify(unchanged.subscribe).called(1);
        room.transportEvents.emit(const sdk.RoomResumingEvent());
        allowed = false;
        room.transportEvents.emit(const sdk.RoomReconnectedEvent());
        await pumpEventQueue();
        check(states.map((event) => event.state).toList()).deepEquals([
          SessionTransportConnectionState.reconnecting,
          SessionTransportConnectionState.connected,
        ]);
        check(states.last.reconnected).isTrue();
        verifyNever(denied.subscribe);
        verifyNever(unchanged.subscribe);
        allowed = true;
        room.transportEvents.emit(
          sdk.TrackSubscriptionPermissionChangedEvent(
            participant: remote,
            publication: denied,
            state: sdk.TrackSubscriptionState.unsubscribed,
          ),
        );
        await pumpEventQueue();
        verify(denied.subscribe).called(1);
        verifyNever(unchanged.subscribe);
      } finally {
        await listener.cancel();
        await transport.dispose();
        await room.transportEvents.dispose();
      }
    },
  );

  test('permission grants retry only current admitted publications', () async {
    final publication = MockRemoteTrackPublication<sdk.RemoteTrack>();
    var allowed = false;
    when(() => publication.subscriptionAllowed).thenAnswer((_) => allowed);
    when(publication.subscribe).thenAnswer((_) async {});
    final remote = _Remote([publication]);
    final room = _Room(MockLocalParticipant())..remotes['remote'] = remote;
    final transport = LiveKitSessionTransport(
      room: room,
      cameraOptions: const sdk.CameraCaptureOptions(),
    );
    void permission(sdk.TrackSubscriptionState state) {
      room.transportEvents.emit(
        sdk.TrackSubscriptionPermissionChangedEvent(
          participant: remote,
          publication: publication,
          state: state,
        ),
      );
    }

    try {
      transport.setIncomingMediaParticipants({'remote'});
      await transport.subscribeToExistingMedia();
      verifyNever(publication.subscribe);
      allowed = true;
      permission(sdk.TrackSubscriptionState.unsubscribed);
      await pumpEventQueue();
      verify(publication.subscribe).called(1);
      permission(sdk.TrackSubscriptionState.unsubscribed);
      await pumpEventQueue();
      verifyNever(publication.subscribe);
      allowed = false;
      permission(sdk.TrackSubscriptionState.notAllowed);
      await pumpEventQueue();
      allowed = true;
      permission(sdk.TrackSubscriptionState.unsubscribed);
      await pumpEventQueue();
      verify(publication.subscribe).called(1);
      when(publication.unsubscribe).thenAnswer((_) async {});
      transport.setIncomingMediaParticipants({});
      await pumpEventQueue();
      permission(sdk.TrackSubscriptionState.unsubscribed);
      await pumpEventQueue();
      verifyNever(publication.subscribe);
      transport.setIncomingMediaParticipants({'remote'});
      await pumpEventQueue();
      verify(publication.subscribe).called(1);
      remote.publications.clear();
      permission(sdk.TrackSubscriptionState.notAllowed);
      permission(sdk.TrackSubscriptionState.unsubscribed);
      await pumpEventQueue();
      verifyNever(publication.subscribe);
    } finally {
      await transport.dispose();
      await room.transportEvents.dispose();
    }
  });

  test(
    'denial during an in-flight subscription does not erase a newer grant',
    () async {
      final publication = MockRemoteTrackPublication<sdk.RemoteTrack>();
      var allowed = true;
      when(() => publication.subscriptionAllowed).thenAnswer((_) => allowed);
      final first = Completer<void>();
      var attempts = 0;
      when(
        publication.subscribe,
      ).thenAnswer((_) => ++attempts == 1 ? first.future : Future.value());
      final remote = _Remote([publication]);
      final room = _Room(MockLocalParticipant())..remotes['remote'] = remote;
      final transport = LiveKitSessionTransport(
        room: room,
        cameraOptions: const sdk.CameraCaptureOptions(),
      );
      try {
        transport.setIncomingMediaParticipants({'remote'});
        final initial = transport.subscribeToExistingMedia();
        allowed = false;
        room.transportEvents.emit(
          sdk.TrackSubscriptionPermissionChangedEvent(
            participant: remote,
            publication: publication,
            state: sdk.TrackSubscriptionState.notAllowed,
          ),
        );
        await pumpEventQueue();
        allowed = true;
        room.transportEvents.emit(
          sdk.TrackSubscriptionPermissionChangedEvent(
            participant: remote,
            publication: publication,
            state: sdk.TrackSubscriptionState.unsubscribed,
          ),
        );
        await pumpEventQueue();
        check(attempts).equals(1);
        first.complete();
        await initial;
        await pumpEventQueue();
        await transport.subscribeToExistingMedia();
        check(attempts).equals(2);
      } finally {
        if (!first.isCompleted) first.complete();
        await transport.dispose();
        await room.transportEvents.dispose();
      }
    },
  );

  test(
    'an authorized unsubscribe event resubscribes the current publication',
    () async {
      final publication = MockRemoteTrackPublication<sdk.RemoteTrack>();
      var subscribed = false;
      var subscribeCalls = 0;
      when(() => publication.subscribed).thenAnswer((_) => subscribed);
      when(publication.subscribe).thenAnswer((_) async {
        subscribeCalls++;
        subscribed = true;
      });
      final remote = _Remote([publication]);
      final room = _Room(MockLocalParticipant())..remotes['remote'] = remote;
      final transport = LiveKitSessionTransport(
        room: room,
        cameraOptions: const sdk.CameraCaptureOptions(),
      );
      try {
        transport.setIncomingMediaParticipants({'remote'});
        await transport.subscribeToExistingMedia();
        subscribed = false;
        room.transportEvents.emit(
          sdk.TrackUnsubscribedEvent(
            participant: remote,
            publication: publication,
            track: MockRemoteVideoTrack(),
          ),
        );
        await pumpEventQueue();

        check(subscribeCalls).equals(2);
        check(subscribed).isTrue();
      } finally {
        await transport.dispose();
        await room.transportEvents.dispose();
      }
    },
  );

  test('transient subscription failures retry authorized current media', () {
    fakeAsync((clock) {
      final publication = MockRemoteTrackPublication<sdk.RemoteTrack>();
      var subscribed = false;
      var attempts = 0;
      when(() => publication.subscribed).thenAnswer((_) => subscribed);
      when(publication.subscribe).thenAnswer((_) async {
        if (++attempts == 1) throw StateError('temporary failure');
        subscribed = true;
      });
      final room = _Room(MockLocalParticipant())
        ..remotes['remote'] = _Remote([publication]);
      final transport = LiveKitSessionTransport(
        room: room,
        cameraOptions: const sdk.CameraCaptureOptions(),
      );
      final errors = <Object>[];
      final listener = transport.events.listen((_) {}, onError: errors.add);
      try {
        transport.setIncomingMediaParticipants({'remote'});
        unawaited(transport.subscribeToExistingMedia().catchError((_) {}));
        clock.flushMicrotasks();
        check(attempts).equals(1);
        check(errors).isEmpty();

        clock
          ..elapse(const Duration(seconds: 1))
          ..flushMicrotasks();
        check(attempts).equals(2);
        check(subscribed).isTrue();
        check(errors).isEmpty();
      } finally {
        unawaited(listener.cancel());
        unawaited(transport.dispose());
        unawaited(room.transportEvents.dispose());
        clock.flushMicrotasks();
      }
    });
  });

  test(
    'incoming roster gates existing and future publications and admits later',
    () async {
      final keeperPublication = MockRemoteTrackPublication<sdk.RemoteTrack>();
      final pendingPublication = MockRemoteTrackPublication<sdk.RemoteTrack>();
      final laterPublication = MockRemoteTrackPublication<sdk.RemoteTrack>();
      for (final publication in [
        keeperPublication,
        pendingPublication,
        laterPublication,
      ]) {
        when(publication.subscribe).thenAnswer((_) async {});
        when(publication.unsubscribe).thenAnswer((_) async {});
      }
      final keeper = _Remote([keeperPublication], 'keeper');
      final pending = _Remote([pendingPublication], 'pending');
      final room = _Room(MockLocalParticipant())
        ..remotes.addAll({'keeper': keeper, 'pending': pending});
      final transport = LiveKitSessionTransport(
        room: room,
        cameraOptions: const sdk.CameraCaptureOptions(),
      );
      try {
        transport.setIncomingMediaParticipants({'keeper'});
        await transport.subscribeToExistingMedia();
        verify(keeperPublication.subscribe).called(1);
        verifyNever(pendingPublication.subscribe);
        room.transportEvents.emit(
          sdk.TrackPublishedEvent(
            participant: pending,
            publication: laterPublication,
          ),
        );
        await pumpEventQueue();
        verifyNever(laterPublication.subscribe);
        pending.publications.add(laterPublication);
        transport.setIncomingMediaParticipants({'keeper', 'pending'});
        await pumpEventQueue();
        verify(pendingPublication.subscribe).called(1);
        verify(laterPublication.subscribe).called(1);
        verifyNever(keeperPublication.subscribe);
        transport.setIncomingMediaParticipants({'keeper'});
        await pumpEventQueue();
        verify(pendingPublication.unsubscribe).called(1);
        verify(laterPublication.unsubscribe).called(1);
        verifyNever(keeperPublication.unsubscribe);
      } finally {
        await transport.dispose();
        await room.transportEvents.dispose();
      }
    },
  );

  test(
    'reconnect preserves existing subscriptions and departures release them',
    () async {
      final publication = MockRemoteTrackPublication<sdk.RemoteTrack>();
      when(publication.subscribe).thenAnswer((_) async {});
      final remote = _Remote([publication]);
      final room = _Room(MockLocalParticipant());
      room.remotes['remote'] = remote;
      final transport = LiveKitSessionTransport(
        room: room,
        cameraOptions: const sdk.CameraCaptureOptions(),
      );
      try {
        room.transportEvents.emit(const sdk.RoomReconnectedEvent());
        await pumpEventQueue();
        verifyNever(publication.subscribe);
        transport.setIncomingMediaParticipants({'remote'});
        await transport.subscribeToExistingMedia();
        await transport.subscribeToExistingMedia();
        verify(publication.subscribe).called(1);
        room.transportEvents.emit(const sdk.RoomReconnectedEvent());
        await pumpEventQueue();
        verifyNever(publication.subscribe);
        remote.publications.clear();
        room.remotes.remove('remote');
        room.transportEvents.emit(
          sdk.ParticipantDisconnectedEvent(participant: remote),
        );
        await pumpEventQueue();
        remote.publications.add(publication);
        room.remotes['remote'] = remote;
        room.transportEvents.emit(
          sdk.ParticipantConnectedEvent(participant: remote),
        );
        await pumpEventQueue();
        await transport.subscribeToExistingMedia();
        verify(publication.subscribe).called(1);
        await transport.disconnect();
        await pumpEventQueue();
        room.transportEvents.emit(const sdk.RoomReconnectedEvent());
        await pumpEventQueue();
        verifyNever(publication.subscribe);
        await transport.connect('url', 'token');
        await transport.subscribeToExistingMedia();
        verify(publication.subscribe).called(1);
        check(room.connections).equals(1);
      } finally {
        await transport.dispose();
        await room.transportEvents.dispose();
      }
    },
  );
  test(
    'reconnect reconciles replacements and independently retries failures',
    () async {
      final original = MockRemoteTrackPublication<sdk.RemoteTrack>();
      final unchanged = MockRemoteTrackPublication<sdk.RemoteTrack>();
      final replacement = MockRemoteTrackPublication<sdk.RemoteTrack>();
      final failing = MockRemoteTrackPublication<sdk.RemoteTrack>();
      when(original.subscribe).thenAnswer((_) async {});
      when(unchanged.subscribe).thenAnswer((_) async {});
      when(replacement.subscribe).thenAnswer((_) async {});
      var attempts = 0;
      when(failing.subscribe).thenAnswer((_) async {
        if (++attempts == 1) throw StateError('subscription failed');
      });
      final remote = _Remote([original, unchanged]);
      final room = _Room(MockLocalParticipant())..remotes['remote'] = remote;
      final transport = LiveKitSessionTransport(
        room: room,
        cameraOptions: const sdk.CameraCaptureOptions(),
      );
      final errors = <Object>[];
      final listener = transport.events.listen((_) {}, onError: errors.add);
      try {
        transport.setIncomingMediaParticipants({'remote'});
        await transport.subscribeToExistingMedia();
        verify(original.subscribe).called(1);
        verify(unchanged.subscribe).called(1);
        remote.publications
          ..remove(original)
          ..addAll([replacement, failing]);
        room.transportEvents.emit(const sdk.RoomReconnectedEvent());
        await pumpEventQueue();
        verifyNever(unchanged.subscribe);
        verify(replacement.subscribe).called(1);
        check(attempts).equals(1);
        check(errors).length.equals(1);
        await transport.subscribeToExistingMedia();
        verifyNever(replacement.subscribe);
        check(attempts).equals(2);
        remote.publications
          ..remove(replacement)
          ..add(original);
        await transport.subscribeToExistingMedia();
        verify(original.subscribe).called(1);
      } finally {
        await listener.cancel();
        await transport.dispose();
        await room.transportEvents.dispose();
      }
    },
  );

  test(
    'LiveKit adapter delivers translated packets and disconnects without leaking SDK events',
    () async {
      final participant = MockLocalParticipant('local');
      when(participant.unpublishAllTracks).thenAnswer((_) async {});
      when(
        () => participant.publishData(
          any(),
          reliable: any(named: 'reliable'),
          topic: any(named: 'topic'),
          destinationIdentities: any(named: 'destinationIdentities'),
        ),
      ).thenAnswer((_) async {});
      final room = _Room(participant);
      final transport = LiveKitSessionTransport(
        room: room,
        cameraOptions: const sdk.CameraCaptureOptions(),
      );
      final events = <SessionTransportEvent>[];
      final subscription = transport.events.listen(events.add);
      try {
        await transport.connect('url', 'token', autoSubscribe: false);
        check(room.connectedOptions!.autoSubscribe).isFalse();
        check(transport.localIdentity).equals('local');
        room.connectionState = sdk.ConnectionState.reconnecting;
        room.transportEvents.emit(const sdk.RoomReconnectingEvent());
        await Future<void>.value();
        check(
          events.whereType<TransportConnectionChanged>().last.state,
        ).equals(SessionTransportConnectionState.reconnecting);
        room.connectionState = sdk.ConnectionState.connected;
        room.transportEvents.emit(const sdk.RoomReconnectedEvent());
        final receivedMetadata = transport.events.firstWhere(
          (event) => event is TransportMetadataChanged,
        );
        final participantLeft = transport.events.firstWhere(
          (event) => event is TransportParticipantChanged && !event.present,
        );
        room.transportEvents.emit(
          const sdk.RoomMetadataChangedEvent(metadata: 'versioned state'),
        );
        final remote = MockRemoteParticipant('keeper', 'Keeper');
        room.transportEvents.emit(
          sdk.ParticipantConnectedEvent(participant: remote),
        );
        room.transportEvents.emit(
          sdk.ParticipantDisconnectedEvent(participant: remote),
        );
        await receivedMetadata;
        await participantLeft;
        check(
          events.whereType<TransportMetadataChanged>().single.metadata,
        ).equals('versioned state');
        check(
          events
              .whereType<TransportParticipantChanged>()
              .map((e) => e.present)
              .toList(),
        ).deepEquals([true, false]);
        transport.setSubscriptionPermissions(
          allowEveryone: false,
          recipients: {'keeper'},
        );

        await transport.publish(
          SessionTransportPacket(
            bytes: [1],
            topic: 'chat',
            reliable: true,
            recipients: ['keeper'],
          ),
        );
        verify(
          () => participant.publishData(
            [1],
            reliable: true,
            topic: 'chat',
            destinationIdentities: ['keeper'],
          ),
        ).called(1);
        final originalPacket = sdk.DataReceivedEvent(
          participant: remote,
          data: [2],
          topic: 'chat',
        );
        room.transportEvents.emit(originalPacket);
        await Future<void>.value();
        check(
          events.whereType<TransportPacketReceived>().single.packet.bytes,
        ).deepEquals([2]);
        // Sender identity survives presence removal without retaining SDK events.
        final received = events
            .whereType<TransportPacketReceived>()
            .single
            .packet;
        check(received.sender?.identity).equals('keeper');
        await transport.disconnect();
        await Future<void>.value();
        check(
          events.whereType<TransportConnectionChanged>().last.reason,
        ).equals(SessionTransportDisconnectReason.clientInitiated);
        await transport.dispose();
        await transport.dispose();
        final count = events.length;
        room.transportEvents.emit(
          const sdk.DataReceivedEvent(
            participant: null,
            data: [3],
            topic: 'chat',
          ),
        );
        await Future<void>.value();
        check(events).length.equals(count);
        check(room.disposals).equals(1);
        verify(participant.unpublishAllTracks).called(1);
      } finally {
        await subscription.cancel();
        await transport.dispose();
        await room.transportEvents.dispose();
      }
    },
  );

  test(
    'SDK failures preserve cause and stack in an application-owned failure',
    () {
      final error = sdk.ConnectException(
        'denied',
        reason: sdk.ConnectionErrorReason.NotAllowed,
      );
      final stack = StackTrace.current;
      final failure = LiveKitSessionTransport.failure(error, stack);
      check(failure.kind).equals(SessionTransportFailureKind.connection);
      check(
        failure.connectionFailure,
      ).equals(SessionTransportConnectionFailure.notAllowed);
      check(identical(failure.cause, error)).isTrue();
      check(identical(failure.stackTrace, stack)).isTrue();
    },
  );
}
