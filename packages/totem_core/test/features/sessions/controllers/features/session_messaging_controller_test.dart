// ignore_for_file: cascade_invocations

import 'dart:convert';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart' hide ConnectionState;
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/features/sessions/controllers/core/session_state.dart';
import 'package:totem_core/features/sessions/controllers/features/session_messaging_controller.dart';
import 'package:totem_core/features/sessions/providers/emoji_reactions_provider.dart';

import '../../livekit_mocks.dart';
import '../core/session_controller_mock.dart';

void main() {
  group('SessionMessagingController', () {
    group('Static Configuration', () {
      test('SessionCommunicationTopics enum has four topics', () {
        check(SessionCommunicationTopics.values).length.equals(4);
      });

      test('SessionCommunicationTopics.emoji has correct topic value', () {
        check(SessionCommunicationTopics.emoji.topic).equals('lk-emoji-topic');
      });

      test('SessionCommunicationTopics.chat has correct topic value', () {
        check(SessionCommunicationTopics.chat.topic).equals('lk-chat-topic');
      });

      test(
        'SessionCommunicationTopics.participantRemoved has correct topic value',
        () {
          check(
            SessionCommunicationTopics.participantRemoved.topic,
          ).equals('lk-participant-removed-topic');
        },
      );

      test(
        'SessionCommunicationTopics.shareTimeReminder has correct topic value',
        () {
          check(
            SessionCommunicationTopics.shareTimeReminder.topic,
          ).equals('lk-share-time-reminder-topic');
        },
      );

      test('All topic values are unique', () {
        final topics = SessionCommunicationTopics.values.map((t) => t.topic);
        check(
          because: 'All topic values should be unique',
          topics,
        ).length.equals(topics.toSet().length);
      });
    });

    group('Data Reception - Emoji Events', () {
      test('handleDataReceived returns true for emoji topic', () async {
        final mockSession = FakeSessionController();
        final container = ProviderContainer();
        final controller = container.read(
          sessionMessagingControllerProvider(mockSession).notifier,
        );

        final emojiEvent = DataReceivedEvent(
          data: utf8.encode('👍'),
          participant: null,
          topic: SessionCommunicationTopics.emoji.topic,
        );

        controller.handleDataReceived(emojiEvent);
      });

      test('handleDataReceived ignores emoji without participant', () async {
        final mockSession = FakeSessionController();
        final container = ProviderContainer();
        final controller = container.read(
          sessionMessagingControllerProvider(mockSession).notifier,
        );

        final emojiEvent2 = DataReceivedEvent(
          data: utf8.encode('👍'),
          participant: null,
          topic: SessionCommunicationTopics.emoji.topic,
        );

        controller.handleDataReceived(emojiEvent2);
      });
    });

    group('Data Reception - Chat Events', () {
      test('handleDataReceived adds chat message for chat topic', () async {
        final mockSession = FakeSessionController();
        final container = ProviderContainer();
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

        controller.handleDataReceived(chatEvent);

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

          final container = ProviderContainer();
          final controller = container.read(
            sessionMessagingControllerProvider(mockSession).notifier,
          );

          final removedData = {'identity': 'user-1', 'reason': 'remove'};

          final removedEvent = DataReceivedEvent(
            data: utf8.encode(jsonEncode(removedData)),
            participant: null,
            topic: SessionCommunicationTopics.participantRemoved.topic,
          );

          controller.handleDataReceived(removedEvent);
        },
      );

      test(
        'handleDataReceived ignores participant removed from non-keeper',
        () async {
          final mockSession = FakeSessionController();

          final container = ProviderContainer();
          final controller = container.read(
            sessionMessagingControllerProvider(mockSession).notifier,
          );

          final removedData2 = {'identity': 'user-2', 'reason': 'remove'};

          final removedEvent2 = DataReceivedEvent(
            data: utf8.encode(jsonEncode(removedData2)),
            participant: null,
            topic: SessionCommunicationTopics.participantRemoved.topic,
          );

          controller.handleDataReceived(removedEvent2);

          check(mockSession.disconnectFromRoomCalled).equals(false);
        },
      );
    });

    group('Data Reception - Share Time Reminder Events', () {
      test(
        'accepts a reminder from the keeper while the local user speaks',
        () {
          final mockSession = FakeSessionController();
          mockSession.mockRoom = FakeRoom(MockLocalParticipant('user-1'));
          mockSession.mockState = SessionRoomState(
            connection: mockSession.mockState.connection,
            participants: mockSession.mockState.participants,
            chat: mockSession.mockState.chat,
            turn: SessionTurnState(
              roomState: mockSession.mockState.roomState.copyWith(
                status: RoomStatus.active,
                turnState: TurnState.idle,
              ),
            ),
          );
          final container = ProviderContainer();
          addTearDown(container.dispose);
          final provider = sessionMessagingControllerProvider(mockSession);
          final controller = container.read(provider.notifier);

          controller.handleDataReceived(
            DataReceivedEvent(
              data: utf8.encode(jsonEncode({'elapsedMilliseconds': 120000})),
              participant: MockRemoteParticipant('keeper-1', 'Keeper'),
              topic: SessionCommunicationTopics.shareTimeReminder.topic,
            ),
          );

          final reminderStart = container.read(provider);
          check(reminderStart).isNotNull();
          check(
            DateTime.timestamp().difference(reminderStart!).inMilliseconds,
          ).isCloseTo(120000, 1000);
        },
      );

      test('ignores a reminder not sent by the keeper', () {
        final mockSession = FakeSessionController();
        mockSession.mockRoom = FakeRoom(MockLocalParticipant('user-1'));
        mockSession.mockState = SessionRoomState(
          connection: mockSession.mockState.connection,
          participants: mockSession.mockState.participants,
          chat: mockSession.mockState.chat,
          turn: SessionTurnState(
            roomState: mockSession.mockState.roomState.copyWith(
              status: RoomStatus.active,
              turnState: TurnState.speaking,
            ),
          ),
        );
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final provider = sessionMessagingControllerProvider(mockSession);
        final controller = container.read(provider.notifier);

        controller.handleDataReceived(
          DataReceivedEvent(
            data: utf8.encode('share-time'),
            participant: MockRemoteParticipant('user-2', 'Participant'),
            topic: SessionCommunicationTopics.shareTimeReminder.topic,
          ),
        );

        check(container.read(provider)).isNull();
      });
    });

    group('Data Reception - Unknown Topics', () {
      test('handleDataReceived returns false for unknown topic', () async {
        final mockSession = FakeSessionController();
        final container = ProviderContainer();
        final controller = container.read(
          sessionMessagingControllerProvider(mockSession).notifier,
        );

        final unknownEvent = DataReceivedEvent(
          data: utf8.encode('data'),
          participant: null,
          topic: 'unknown-topic',
        );

        controller.handleDataReceived(unknownEvent);
      });
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

          final before = container.read(emojiReactionsProvider);
          check(before).isEmpty();

          await controller.sendReaction('👍');

          final after = container.read(emojiReactionsProvider);
          check(after).length.equals(1);
          check(after.first.emoji).equals('👍');
        },
      );
    });

    group('Send Share Time Reminder', () {
      test('sends reliable data only to the current speaker', () async {
        final keeper = MockLocalParticipant('keeper-1');
        when(
          () => keeper.publishData(
            any(),
            reliable: true,
            destinationIdentities: const ['user-1'],
            topic: SessionCommunicationTopics.shareTimeReminder.topic,
          ),
        ).thenAnswer((_) async {});
        final mockSession = FakeSessionController()
          ..isCurrentUserKeeperValue = true
          ..mockRoom = FakeRoom(keeper);
        final turnStartedAt = DateTime.timestamp().subtract(
          const Duration(minutes: 2),
        );
        mockSession.mockState = SessionRoomState(
          connection: mockSession.mockState.connection,
          participants: mockSession.mockState.participants,
          chat: mockSession.mockState.chat,
          turn: SessionTurnState(
            roomState: mockSession.mockState.roomState.copyWith(
              status: RoomStatus.active,
              turnState: TurnState.idle,
            ),
          ),
          turnStartedAt: turnStartedAt,
        );
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(
          sessionMessagingControllerProvider(mockSession).notifier,
        );

        await controller.sendShareTimeReminder('user-1');

        final data =
            verify(
                  () => keeper.publishData(
                    captureAny(),
                    reliable: true,
                    destinationIdentities: const ['user-1'],
                    topic: SessionCommunicationTopics.shareTimeReminder.topic,
                  ),
                ).captured.single
                as List<int>;
        final payload = jsonDecode(utf8.decode(data)) as Map<String, dynamic>;
        check(payload['elapsedMilliseconds'] as num).isCloseTo(120000, 1000);
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

          expect(accepted, isFalse);
          expect(mockSession.addedChatMessages, isEmpty);
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

        final container = ProviderContainer();
        final controller = container.read(
          sessionMessagingControllerProvider(mockSession).notifier,
        );

        await controller.sendMessage('Hi Lucas', recipientIdentity: 'lucas');

        expect(mockSession.addedChatMessages, hasLength(1));
        expect(mockSession.addedChatMessages.first.recipientIdentity, 'lucas');
        expect(
          mockSession.addedChatMessages.first.toMap()['recipientIdentity'],
          'lucas',
        );
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
        final controller = container.read(
          sessionMessagingControllerProvider(mockSession).notifier,
        );

        await controller.sendMessage(
          'I need help',
          recipientIdentity: 'keeper-1',
        );

        expect(mockSession.addedChatMessages, hasLength(1));
        expect(
          mockSession.addedChatMessages.first.recipientIdentity,
          'keeper-1',
        );
      });

      test('participant cannot DM another participant', () async {
        final mockSession = FakeSessionController();
        mockSession.isCurrentUserKeeperValue = false;

        final container = ProviderContainer();
        final controller = container.read(
          sessionMessagingControllerProvider(mockSession).notifier,
        );

        final accepted = await controller.sendMessage(
          'Nope',
          recipientIdentity: 'lucas',
        );

        // The composer relies on this to keep the user's text.
        expect(accepted, isFalse);
        expect(mockSession.addedChatMessages, isEmpty);
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
        final controller = container.read(
          sessionMessagingControllerProvider(mockSession).notifier,
        );

        controller.handleDataReceived(
          privateChatEvent(
            senderIdentity: 'lucas',
            recipientIdentity: 'user-2',
          ),
        );

        expect(mockSession.addedChatMessages, isEmpty);
      });

      test('accepts a DM from the keeper', () async {
        final mockSession = FakeSessionController()
          ..mockRoom = FakeRoom(MockLocalParticipant('user-2'));
        final container = ProviderContainer();
        final controller = container.read(
          sessionMessagingControllerProvider(mockSession).notifier,
        );

        controller.handleDataReceived(
          privateChatEvent(
            senderIdentity: 'keeper-1',
            recipientIdentity: 'user-2',
          ),
        );

        expect(mockSession.addedChatMessages, hasLength(1));
        expect(mockSession.addedChatMessages.first.recipientIdentity, 'user-2');
      });

      test('keeper accepts a DM addressed to them', () async {
        final mockSession = FakeSessionController()
          ..mockRoom = FakeRoom(MockLocalParticipant('keeper-1'));
        final container = ProviderContainer();
        final controller = container.read(
          sessionMessagingControllerProvider(mockSession).notifier,
        );

        controller.handleDataReceived(
          privateChatEvent(
            senderIdentity: 'lucas',
            recipientIdentity: 'keeper-1',
          ),
        );

        expect(mockSession.addedChatMessages, hasLength(1));
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
            privateChatEvent(
              senderIdentity: 'lucas',
              recipientIdentity: 'keeper-1',
            ),
          );

          expect(mockSession.addedChatMessages, isEmpty);
        },
      );

      test('ignores Everyone messages without a sender', () async {
        final mockSession = FakeSessionController();
        final container = ProviderContainer();
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

        controller.handleDataReceived(chatEvent);

        check(mockSession.addedChatMessages).isEmpty();
      });

      test('ignores Everyone messages from a non-keeper sender', () async {
        final mockSession = FakeSessionController();
        final container = ProviderContainer();
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

        controller.handleDataReceived(chatEvent);

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
          participant: MockLocalParticipant('keeper-1'),
        );

        expect(
          everyone.belongsToThread(
            localIdentity: 'keeper-1',
            threadTarget: null,
          ),
          isTrue,
        );
        expect(
          private.belongsToThread(
            localIdentity: 'keeper-1',
            threadTarget: null,
          ),
          isFalse,
        );
        expect(
          private.belongsToThread(
            localIdentity: 'keeper-1',
            threadTarget: 'lucas',
          ),
          isTrue,
        );
        expect(
          everyone.belongsToThread(
            localIdentity: 'keeper-1',
            threadTarget: 'lucas',
          ),
          isFalse,
        );
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
          participant: MockRemoteParticipant('lucas', 'Lucas'),
        );
        final echo = SessionChatMessage(
          id: 'd2',
          sender: false,
          message: 'hang tight',
          timestamp: 3,
          recipientIdentity: 'lucas',
          participant: MockRemoteParticipant('keeper-1', 'Heather'),
        );
        final sent = SessionChatMessage(
          id: 'd3',
          sender: true,
          message: 'hang tight',
          timestamp: 4,
          recipientIdentity: 'lucas',
          participant: MockLocalParticipant('keeper-1'),
        );

        expect(everyone.threadTargetFor('keeper-1'), isNull);
        expect(incoming.threadTargetFor('keeper-1'), 'lucas');
        expect(incoming.threadTargetFor('lucas'), 'keeper-1');
        expect(echo.threadTargetFor('keeper-1'), 'lucas');
        expect(sent.threadTargetFor('keeper-1'), 'lucas');
      });
    });
  });
}
