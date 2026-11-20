// ignore_for_file: cascade_invocations

import 'dart:convert';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart' hide ConnectionState;
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

import 'package:totem_core/features/sessions/controllers/core/session_state.dart';
import 'package:totem_core/features/sessions/controllers/features/session_messaging_controller.dart';

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

    group('Send Message', () {
      test('adds a message after reliable publication succeeds', () async {
        final keeper = MockLocalParticipant('keeper-1');
        when(
          () => keeper.publishData(
            any(),
            reliable: true,
            destinationIdentities: const ['user-1', 'user-2'],
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

        verify(
          () => keeper.publishData(
            any(),
            reliable: true,
            destinationIdentities: const ['user-1', 'user-2'],
            topic: SessionCommunicationTopics.chat.topic,
          ),
        ).called(1);
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
            destinationIdentities: const ['user-1', 'user-2'],
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

        verify(
          () => keeper.publishData(
            any(),
            reliable: true,
            destinationIdentities: const ['user-1', 'user-2'],
            topic: SessionCommunicationTopics.chat.topic,
          ),
        ).called(1);
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

        mockSession.mockState = SessionRoomState(
          connection: mockSession.mockState.connection,
          participants: mockSession.mockState.participants.copyWith(
            participants: [
              ...mockSession.mockState.participantsList,
              testParticipant('lucas'),
            ],
          ),
          turn: mockSession.mockState.turn,
        );
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
