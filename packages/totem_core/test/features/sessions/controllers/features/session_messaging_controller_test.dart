// ignore_for_file: cascade_invocations

import 'dart:async';
import 'dart:convert';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart'
    as livekit
    show ConnectionState;
import 'package:livekit_client/livekit_client.dart' hide ConnectionState;
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';
import 'package:totem_core/features/sessions/admission/admission_protocol.dart';
import 'package:totem_core/features/sessions/admission/session_admission_service.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/controllers/features/session_messaging_controller.dart';
import 'package:totem_core/features/sessions/providers/emoji_reactions_provider.dart';
import 'package:totem_core/features/sessions/transport/session_transport.dart';

import '../../livekit_mocks.dart';
import '../../media/test_participants.dart';
import '../../media/test_room_transport.dart';
import '../../transport/fake_session_transport.dart';
import '../core/session_controller_mock.dart';

void main() {
  group('SessionMessagingController', () {
    test('publishes the stable topic names used by session peers', () {
      final topicNames = <SessionCommunicationTopics, String>{
        SessionCommunicationTopics.emoji: 'lk-emoji-topic',
        SessionCommunicationTopics.chat: 'lk-chat-topic',
        SessionCommunicationTopics.participantRemoved:
            'lk-participant-removed-topic',
      };

      check(SessionCommunicationTopics.values).length.equals(topicNames.length);
      check(
        SessionCommunicationTopics.values.every(
          (topic) => topic.topic == topicNames[topic],
        ),
      ).isTrue();
      check(topicNames.values.toSet()).length.equals(topicNames.length);
    });

    test('receives an emoji only when its sender is known', () {
      final mockSession = FakeSessionController();
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(
        sessionMessagingControllerProvider(mockSession).notifier,
      );

      controller.handleDataReceived(
        packetFromSdk(
          DataReceivedEvent(
            data: utf8.encode('👍'),
            participant: MockRemoteParticipant('participant-1', 'Participant'),
            topic: SessionCommunicationTopics.emoji.topic,
          ),
        ),
      );

      final reactions = mockSession.receivedReactions;
      check(reactions).length.equals(1);
      check(reactions.single.$1).equals('participant-1');
      check(reactions.single.$2).equals('👍');

      controller.handleDataReceived(
        packetFromSdk(
          DataReceivedEvent(
            data: utf8.encode('👎'),
            participant: null,
            topic: SessionCommunicationTopics.emoji.topic,
          ),
        ),
      );

      check(mockSession.receivedReactions).length.equals(1);
    });

    group('Data Reception - Chat Events', () {
      test('handleDataReceived adds chat message for chat topic', () async {
        final mockSession = FakeSessionController();
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(
          sessionMessagingControllerProvider(mockSession).notifier,
        );

        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final messageData = {
          'message': 'Hello',
          'timestamp': timestamp,
          'id': 'msg-1',
        };

        final chatEvent = DataReceivedEvent(
          data: utf8.encode(jsonEncode(messageData)),
          participant: MockRemoteParticipant('keeper-1', 'Keeper'),
          topic: SessionCommunicationTopics.chat.topic,
        );

        controller.handleDataReceived(packetFromSdk(chatEvent));

        check(mockSession.addedChatMessages).isNotEmpty();
        check(mockSession.addedChatMessages.first.message).equals('Hello');
      });
    });

    group('Data Reception - Participant Removed Events', () {
      test(
        'handleDataReceived processes participant removed when keeper',
        () async {
          final mockSession = FakeSessionController();
          mockSession.isCurrentUserKeeperValue = true;
          mockSession.mockRoom = FakeRoom(MockLocalParticipant('user-1'));

          final container = ProviderContainer();
          addTearDown(container.dispose);
          final controller = container.read(
            sessionMessagingControllerProvider(mockSession).notifier,
          );

          final removedData = {'identity': 'user-1', 'reason': 'remove'};

          final removedEvent = DataReceivedEvent(
            data: utf8.encode(jsonEncode(removedData)),
            participant: null,
            topic: SessionCommunicationTopics.participantRemoved.topic,
          );

          controller.handleDataReceived(packetFromSdk(removedEvent));

          check(mockSession.disconnectFromRoomCalled).equals(true);
        },
      );

      test(
        'handleDataReceived ignores participant removed from non-keeper',
        () async {
          final mockSession = FakeSessionController();

          final container = ProviderContainer();
          addTearDown(container.dispose);
          final controller = container.read(
            sessionMessagingControllerProvider(mockSession).notifier,
          );

          final removedData2 = {'identity': 'user-2', 'reason': 'remove'};

          final removedEvent2 = DataReceivedEvent(
            data: utf8.encode(jsonEncode(removedData2)),
            participant: null,
            topic: SessionCommunicationTopics.participantRemoved.topic,
          );

          controller.handleDataReceived(packetFromSdk(removedEvent2));

          check(mockSession.disconnectFromRoomCalled).equals(false);
        },
      );
    });

    group('Send Reaction', () {
      test(
        'sendReaction updates emojiReactionsProvider when keeper exists',
        () async {
          final mockSession = FakeSessionController();
          final container = ProviderContainer();
          addTearDown(container.dispose);

          final controller = container.read(
            sessionMessagingControllerProvider(mockSession).notifier,
          );

          mockSession.mockTransport = FakeSessionTransport()
            ..connectionState = SessionTransportConnectionState.connected;
          final before = mockSession.receivedReactions.toList();
          check(before).isEmpty();

          await controller.sendReaction('👍');

          final after = mockSession.receivedReactions;
          check(after).length.equals(1);
          check(after.first.$2).equals('👍');
        },
      );
    });

    group('Admission receipt', () {
      AdmissionRequest request({String sender = 'user-1'}) => AdmissionRequest(
        id: 'attempt-1',
        senderIdentity: sender,
        recipientIdentity: 'keeper-1',
        expiresAt: DateTime.now().add(const Duration(minutes: 1)),
        displayName: 'Guest',
      );

      test(
        'publishes to the keeper and retries on hello until teardown',
        () async {
          final participant = MockLocalParticipant('user-1');
          final published = <List<int>>[];
          when(
            () => participant.publishData(
              any(),
              reliable: true,
              destinationIdentities: ['keeper-1'],
              topic: AdmissionProtocol.topic,
            ),
          ).thenAnswer((invocation) async {
            published.add(invocation.positionalArguments.single as List<int>);
          });
          final room = _ReceiptRoom(participant);
          final session = FakeSessionController()..mockRoom = room;
          final container = ProviderContainer();
          addTearDown(container.dispose);
          final subscription = container.listen(
            sessionMessagingControllerProvider(session),
            (_, _) {},
          );
          addTearDown(subscription.close);
          final controller = container.read(
            sessionMessagingControllerProvider(session).notifier,
          );
          _attachAdmission(container, session);
          final attempt = request();

          await controller.sendAdmissionJoined(attempt);

          check(room.listenerCount).equals(1);
          check(published).length.equals(1);
          final receipt = AdmissionProtocol.decode(
            published.single,
            senderIdentity: 'user-1',
            now: DateTime.now(),
          );
          check(receipt).isA<AdmissionJoined>();
          check(receipt?.id).equals(attempt.id);
          check(receipt?.recipientIdentity).equals('keeper-1');
          controller.handleDataReceived(
            packetFromSdk(
              DataReceivedEvent(
                data: published.single,
                participant: MockRemoteParticipant('user-1', 'Guest'),
                topic: AdmissionProtocol.topic,
              ),
            ),
          );
          check(session.addedChatMessages).isEmpty();
          check(container.read(emojiReactionsProvider)).isEmpty();

          await room.listener.trigger(
            DataReceivedEvent(
              data: AdmissionProtocol.encode(
                AdmissionHello(
                  id: 'hello',
                  senderIdentity: 'keeper-1',
                  recipientIdentity: 'user-1',
                  expiresAt: attempt.expiresAt,
                ),
              ),
              participant: MockRemoteParticipant('keeper-1', 'Keeper'),
              topic: AdmissionProtocol.topic,
            ),
          );
          await Future<void>.value();
          check(published).length.equals(2);
          await room.listener.trigger(const RoomReconnectedEvent());
          await Future<void>.value();
          check(published).length.equals(3);
          await check(
            controller.sendAdmissionJoined(attempt),
          ).throws<StateError>();
          check(room.listenerCount).equals(1);

          await session.admission.disconnect();
          await session.admission.disconnect();
          check(
            room.listener.disposeCount,
          ).equals(0); // Runtime still owns its listener.
          await room.listener.trigger(const RoomReconnectedEvent());
          check(published).length.equals(3);
        },
      );

      test('rejects an unjoined room or a different local identity', () async {
        final room = _ReceiptRoom(MockLocalParticipant('user-1'));
        final session = FakeSessionController()..mockRoom = room;
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(
          sessionMessagingControllerProvider(session).notifier,
        );
        _attachAdmission(container, session);
        session.mockState = SessionRoomState(
          connection: session.state.connection.copyWith(
            state: RoomConnectionState.disconnected,
          ),
          participants: session.state.participants,

          turn: session.state.turn,
        );

        await check(
          controller.sendAdmissionJoined(request()),
        ).throws<StateError>();
        check(
          room.listenerCount,
        ).equals(1); // The fixture transport, not admission, owns the listener.
        session.mockState = SessionRoomState(
          connection: session.state.connection.copyWith(
            state: RoomConnectionState.connected,
          ),
          participants: session.state.participants,

          turn: session.state.turn,
        );
        await check(
          controller.sendAdmissionJoined(request(sender: 'other')),
        ).throws<StateError>();
        check(
          room.listenerCount,
        ).equals(1); // The fixture transport, not admission, owns the listener.
      });

      test(
        'sends failure from a connected adopted room before session state connects, and skips a disconnected room',
        () async {
          final participant = MockLocalParticipant('user-1');
          final published = <List<int>>[];
          when(
            () => participant.publishData(
              any(),
              reliable: true,
              destinationIdentities: ['keeper-1'],
              topic: AdmissionProtocol.topic,
            ),
          ).thenAnswer((invocation) async {
            published.add(invocation.positionalArguments.single as List<int>);
          });
          final room = _ReceiptRoom(participant);
          final session = FakeSessionController()..mockRoom = room;
          session.mockState = SessionRoomState(
            connection: session.state.connection.copyWith(
              state: RoomConnectionState.connecting,
            ),
            participants: session.state.participants,

            turn: session.state.turn,
          );
          final container = ProviderContainer();
          addTearDown(container.dispose);
          final controller = container.read(
            sessionMessagingControllerProvider(session).notifier,
          );
          _attachAdmission(container, session);
          final attempt = request();
          await controller.sendAdmissionJoinFailed(attempt);
          final receipt = AdmissionProtocol.decode(
            published.single,
            senderIdentity: 'user-1',
            now: DateTime.now(),
          );
          check(receipt).isA<AdmissionJoinFailed>();
          check(receipt?.id).equals(attempt.id);
          check(receipt?.recipientIdentity).equals('keeper-1');
          await session.admission.disconnect();
          room.connected = false;
          await check(
            controller.sendAdmissionJoinFailed(attempt),
          ).throws<StateError>();
          check(published).length.equals(1);
        },
      );

      test('releases the retained listener on provider disposal', () async {
        final participant = MockLocalParticipant('user-1');
        when(
          () => participant.publishData(
            any(),
            reliable: true,
            destinationIdentities: ['keeper-1'],
            topic: AdmissionProtocol.topic,
          ),
        ).thenAnswer((_) async {});
        final room = _ReceiptRoom(participant);
        final session = FakeSessionController()..mockRoom = room;
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(
          sessionMessagingControllerProvider(session).notifier,
        );

        _attachAdmission(container, session);
        await controller.sendAdmissionJoined(request());
        container.dispose();
        await session.admission.close();
        check(
          room.listener.disposeCount,
        ).equals(0); // Only the admission channel was closed.
        await check(
          controller.sendAdmissionJoined(request()),
        ).throws<StateError>();
        check(room.listenerCount).equals(1);
      });
    });

    group('Send Message', () {
      test('adds a message after reliable publication succeeds', () async {
        final keeper = MockLocalParticipant('keeper-1');
        when(
          () => keeper.publishData(
            any(),
            reliable: true,
            destinationIdentities: null,
            topic: SessionCommunicationTopics.chat.topic,
          ),
        ).thenAnswer((_) async {});
        final mockSession = FakeSessionController()
          ..isCurrentUserKeeperValue = true
          ..mockRoom = FakeRoom(keeper);

        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(
          sessionMessagingControllerProvider(mockSession).notifier,
        );

        final accepted = await controller.sendMessage('Hello everyone!');

        check(accepted).isTrue();
        check(mockSession.addedChatMessages).isNotEmpty();
        check(
          mockSession.addedChatMessages.first.message,
        ).equals('Hello everyone!');
        check(mockSession.addedChatMessages.first.recipientIdentity).isNull();
      });

      test('does not add a message when the room is unavailable', () async {
        final mockSession = FakeSessionController()
          ..isCurrentUserKeeperValue = true;
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(
          sessionMessagingControllerProvider(mockSession).notifier,
        );

        final accepted = await controller.sendMessage('Hello everyone!');

        check(accepted).isFalse();
        check(mockSession.addedChatMessages).isEmpty();
      });

      test('does not add a message when publication fails', () async {
        final keeper = MockLocalParticipant('keeper-1');
        when(
          () => keeper.publishData(
            any(),
            reliable: true,
            destinationIdentities: null,
            topic: SessionCommunicationTopics.chat.topic,
          ),
        ).thenThrow(StateError('publication failed'));
        final mockSession = FakeSessionController()
          ..isCurrentUserKeeperValue = true
          ..mockRoom = FakeRoom(keeper);
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(
          sessionMessagingControllerProvider(mockSession).notifier,
        );

        final accepted = await controller.sendMessage('Hello everyone!');

        check(accepted).isFalse();
        check(mockSession.addedChatMessages).isEmpty();
      });

      test(
        'sendMessage logs warning when not keeper posts to Everyone',
        () async {
          final mockSession = FakeSessionController();
          mockSession.isCurrentUserKeeperValue = false;

          final container = ProviderContainer();
          final controller = container.read(
            sessionMessagingControllerProvider(mockSession).notifier,
          );

          final accepted = await controller.sendMessage('Hello');

          check(accepted).isFalse();
          check(mockSession.addedChatMessages).isEmpty();
        },
      );

      test('keeper can send a private message', () async {
        final keeper = MockLocalParticipant('keeper-1');
        when(
          () => keeper.publishData(
            any(),
            reliable: true,
            destinationIdentities: const ['lucas'],
            topic: SessionCommunicationTopics.chat.topic,
          ),
        ).thenAnswer((_) async {});
        final mockSession = FakeSessionController()
          ..isCurrentUserKeeperValue = true
          ..mockRoom = FakeRoom(keeper);

        mockSession.mockTransport = FakeSessionTransport()
          ..localIdentity = 'keeper-1'
          ..connectionState = SessionTransportConnectionState.connected
          ..participants = [
            testParticipant('keeper-1', isLocal: true),
            testParticipant('lucas'),
          ];
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(
          sessionMessagingControllerProvider(mockSession).notifier,
        );

        await controller.sendMessage('Hi Lucas', recipientIdentity: 'lucas');

        check(mockSession.addedChatMessages).length.equals(1);
        check(
          mockSession.addedChatMessages.first.recipientIdentity,
        ).equals('lucas');
        check(
          mockSession.addedChatMessages.first.toMap()['recipientIdentity'],
        ).equals('lucas');
      });

      test('participant can send a private message to the keeper', () async {
        final participant = MockLocalParticipant('user-1');
        when(
          () => participant.publishData(
            any(),
            reliable: true,
            destinationIdentities: const ['keeper-1'],
            topic: SessionCommunicationTopics.chat.topic,
          ),
        ).thenAnswer((_) async {});
        final mockSession = FakeSessionController()
          ..isCurrentUserKeeperValue = false
          ..mockRoom = FakeRoom(participant);

        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(
          sessionMessagingControllerProvider(mockSession).notifier,
        );

        await controller.sendMessage(
          'I need help',
          recipientIdentity: 'keeper-1',
        );

        check(mockSession.addedChatMessages).length.equals(1);
        check(
          mockSession.addedChatMessages.first.recipientIdentity,
        ).equals('keeper-1');
      });

      test('participant cannot DM another participant', () async {
        final mockSession = FakeSessionController();
        mockSession.isCurrentUserKeeperValue = false;

        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(
          sessionMessagingControllerProvider(mockSession).notifier,
        );

        final accepted = await controller.sendMessage(
          'Nope',
          recipientIdentity: 'lucas',
        );

        // The composer relies on this to keep the user's text.
        check(accepted).isFalse();
        check(mockSession.addedChatMessages).isEmpty();
      });

      DataReceivedEvent privateChatEvent({
        required String senderIdentity,
        required String recipientIdentity,
        String id = 'dm-1',
      }) {
        return DataReceivedEvent(
          data: utf8.encode(
            jsonEncode({
              'message': 'Private',
              'timestamp': 1,
              'id': id,
              'recipientIdentity': recipientIdentity,
            }),
          ),
          participant: MockRemoteParticipant(senderIdentity, senderIdentity),
          topic: SessionCommunicationTopics.chat.topic,
        );
      }

      test('ignores a participant-to-participant DM', () async {
        // LiveKit lets a patched client publish straight to another
        // participant; the receive side has to drop it.
        final mockSession = FakeSessionController()
          ..mockRoom = FakeRoom(MockLocalParticipant('user-2'));
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(
          sessionMessagingControllerProvider(mockSession).notifier,
        );

        controller.handleDataReceived(
          packetFromSdk(
            privateChatEvent(
              senderIdentity: 'lucas',
              recipientIdentity: 'user-2',
            ),
          ),
        );

        check(mockSession.addedChatMessages).isEmpty();
      });

      test('accepts a DM from the keeper', () async {
        final mockSession = FakeSessionController()
          ..mockRoom = FakeRoom(MockLocalParticipant('user-2'));
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(
          sessionMessagingControllerProvider(mockSession).notifier,
        );

        controller.handleDataReceived(
          packetFromSdk(
            privateChatEvent(
              senderIdentity: 'keeper-1',
              recipientIdentity: 'user-2',
            ),
          ),
        );

        check(mockSession.addedChatMessages).length.equals(1);
        check(
          mockSession.addedChatMessages.first.recipientIdentity,
        ).equals('user-2');
      });

      test('ignores a keeper DM delivered to another participant', () async {
        final mockSession = FakeSessionController()
          ..mockRoom = FakeRoom(MockLocalParticipant('bob'));
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(
          sessionMessagingControllerProvider(mockSession).notifier,
        );

        controller.handleDataReceived(
          packetFromSdk(
            privateChatEvent(
              senderIdentity: 'keeper-1',
              recipientIdentity: 'alice',
            ),
          ),
        );

        check(mockSession.addedChatMessages).isEmpty();
      });

      test('keeper accepts a DM addressed to them', () async {
        final mockSession = FakeSessionController()
          ..mockRoom = FakeRoom(MockLocalParticipant('keeper-1'));
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(
          sessionMessagingControllerProvider(mockSession).notifier,
        );

        controller.handleDataReceived(
          packetFromSdk(
            privateChatEvent(
              senderIdentity: 'lucas',
              recipientIdentity: 'keeper-1',
            ),
          ),
        );

        check(mockSession.addedChatMessages).length.equals(1);
      });

      test(
        'ignores a DM to the keeper that was fanned out to others',
        () async {
          // Same payload as above, but delivered to a non-keeper client.
          final mockSession = FakeSessionController()
            ..mockRoom = FakeRoom(MockLocalParticipant('user-2'));
          final container = ProviderContainer();
          final controller = container.read(
            sessionMessagingControllerProvider(mockSession).notifier,
          );

          controller.handleDataReceived(
            packetFromSdk(
              privateChatEvent(
                senderIdentity: 'lucas',
                recipientIdentity: 'keeper-1',
              ),
            ),
          );

          check(mockSession.addedChatMessages).isEmpty();
        },
      );

      test('ignores Everyone messages without a sender', () async {
        final mockSession = FakeSessionController();
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(
          sessionMessagingControllerProvider(mockSession).notifier,
        );

        final chatEvent = DataReceivedEvent(
          data: utf8.encode(
            jsonEncode({
              'message': 'Unattributed',
              'timestamp': 1,
              'id': 'bad-0',
            }),
          ),
          participant: null,
          topic: SessionCommunicationTopics.chat.topic,
        );

        controller.handleDataReceived(packetFromSdk(chatEvent));

        check(mockSession.addedChatMessages).isEmpty();
      });

      test('ignores Everyone messages from a non-keeper sender', () async {
        final mockSession = FakeSessionController();
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(
          sessionMessagingControllerProvider(mockSession).notifier,
        );

        final chatEvent = DataReceivedEvent(
          data: utf8.encode(
            jsonEncode({'message': 'Hijack', 'timestamp': 1, 'id': 'bad-1'}),
          ),
          participant: MockRemoteParticipant('lucas', 'Lucas'),
          topic: SessionCommunicationTopics.chat.topic,
        );

        controller.handleDataReceived(packetFromSdk(chatEvent));

        check(mockSession.addedChatMessages).isEmpty();
      });
    });

    group('Thread filtering', () {
      test('belongsToThread keeps Everyone and private messages apart', () {
        const everyone = SessionChatMessage(
          id: 'g1',
          sender: true,
          message: 'hi all',
          timestamp: 1,
        );
        final private = SessionChatMessage(
          id: 'd1',
          sender: true,
          message: 'hi lucas',
          timestamp: 2,
          recipientIdentity: 'lucas',
          participant: testParticipant('keeper-1', isLocal: true),
        );

        check(
          everyone.belongsToThread(
            localIdentity: 'keeper-1',
            threadTarget: null,
          ),
        ).isTrue();
        check(
          private.belongsToThread(
            localIdentity: 'keeper-1',
            threadTarget: null,
          ),
        ).isFalse();
        check(
          private.belongsToThread(
            localIdentity: 'keeper-1',
            threadTarget: 'lucas',
          ),
        ).isTrue();
        check(
          everyone.belongsToThread(
            localIdentity: 'keeper-1',
            threadTarget: 'lucas',
          ),
        ).isFalse();
      });

      test('threadTargetFor opens the other party, not Everyone', () {
        const everyone = SessionChatMessage(
          id: 'g1',
          sender: false,
          message: 'hi all',
          timestamp: 1,
        );
        final incoming = SessionChatMessage(
          id: 'd1',
          sender: false,
          message: 'need help',
          timestamp: 2,
          recipientIdentity: 'keeper-1',
          participant: testParticipant('lucas', name: 'Lucas'),
        );
        final echo = SessionChatMessage(
          id: 'd2',
          sender: false,
          message: 'hang tight',
          timestamp: 3,
          recipientIdentity: 'lucas',
          participant: testParticipant('keeper-1', name: 'Heather'),
        );
        final sent = SessionChatMessage(
          id: 'd3',
          sender: true,
          message: 'hang tight',
          timestamp: 4,
          recipientIdentity: 'lucas',
          participant: testParticipant('keeper-1', isLocal: true),
        );

        check(everyone.threadTargetFor('keeper-1')).isNull();
        check(incoming.threadTargetFor('keeper-1')).equals('lucas');
        check(incoming.threadTargetFor('lucas')).equals('keeper-1');
        check(echo.threadTargetFor('keeper-1')).equals('lucas');
        check(sent.threadTargetFor('keeper-1')).equals('lucas');
      });
    });
  });
}

class _ReceiptRoom extends FakeRoom {
  _ReceiptRoom(super.participant);

  final listener = _ReceiptEvents();
  int listenerCount = 0;
  bool connected = true;

  @override
  livekit.ConnectionState get connectionState => connected
      ? livekit.ConnectionState.connected
      : livekit.ConnectionState.disconnected;

  @override
  String? get metadata => null;

  @override
  EventsListener<RoomEvent> createListener({bool synchronized = true}) {
    listenerCount++;
    return listener;
  }
}

class _ReceiptEvents implements EventsListener<RoomEvent> {
  final handlers = <Type, List<FutureOr<void> Function(Object?)>>{};
  final disposed = Completer<void>();
  int disposeCount = 0;

  @override
  CancelListenFunc on<E>(
    FutureOr<void> Function(E event) handler, {
    bool Function(E)? filter,
  }) {
    handlers.putIfAbsent(E, () => []).add((event) {
      final typed = event as E;
      if (filter == null || filter(typed)) return handler(typed);
    });
    return () async {};
  }

  Future<void> trigger<E>(E event) async {
    if (disposeCount > 0) return;
    for (final handler in handlers[E] ?? <FutureOr<void> Function(Object?)>[]) {
      await handler(event);
    }
  }

  @override
  Future<bool> dispose() async {
    disposeCount++;
    disposed.complete();
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void _attachAdmission(
  ProviderContainer container,
  FakeSessionController session,
) {
  final provider = Provider<SessionAdmissionService>((ref) {
    final service = SessionAdmissionService(ref, session);
    final subscription = session.transport!.events.listen(
      service.handleTransportEvent,
    );
    ref.onDispose(() {
      unawaited(subscription.cancel());
      unawaited(service.close());
    });
    return service;
  });
  session.admission = container.read(provider);
}
