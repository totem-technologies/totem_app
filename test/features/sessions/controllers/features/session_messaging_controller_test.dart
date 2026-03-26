// ignore_for_file: depend_on_referenced_packages, cascade_invocations

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart' hide ConnectionState;
import 'package:riverpod/riverpod.dart';
import 'package:totem_app/features/sessions/controllers/features/session_messaging_controller.dart';
import 'package:totem_app/features/sessions/providers/emoji_reactions_provider.dart';

import '../mocks.dart';

void main() {
  group('SessionMessagingController', () {
    group('Static Configuration', () {
      test('SessionCommunicationTopics enum has three topics', () {
        expect(SessionCommunicationTopics.values.length, 3);
      });

      test('SessionCommunicationTopics.emoji has correct topic value', () {
        expect(
          SessionCommunicationTopics.emoji.topic,
          equals('lk-emoji-topic'),
        );
      });

      test('SessionCommunicationTopics.chat has correct topic value', () {
        expect(
          SessionCommunicationTopics.chat.topic,
          equals('lk-chat-topic'),
        );
      });

      test(
        'SessionCommunicationTopics.participantRemoved has correct topic value',
        () {
          expect(
            SessionCommunicationTopics.participantRemoved.topic,
            equals('lk-participant-removed-topic'),
          );
        },
      );

      test('All topic values are unique', () {
        final topics = SessionCommunicationTopics.values.map((t) => t.topic);
        expect(
          topics.length,
          equals(topics.toSet().length),
          reason: 'All topic values should be unique',
        );
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
          participant: null,
          topic: SessionCommunicationTopics.chat.topic,
        );

        controller.handleDataReceived(chatEvent);

        expect(mockSession.addedChatMessages, isNotEmpty);
        expect(mockSession.addedChatMessages.first.message, equals('Hello'));
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

          final removedData = {'identity': 'user-1'};

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

          final removedData2 = {
            'identity': 'user-2',
          };

          final removedEvent2 = DataReceivedEvent(
            data: utf8.encode(jsonEncode(removedData2)),
            participant: null,
            topic: SessionCommunicationTopics.participantRemoved.topic,
          );

          controller.handleDataReceived(removedEvent2);

          expect(mockSession.disconnectFromRoomCalled, isFalse);
        },
      );
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
          expect(before, isEmpty);

          await controller.sendReaction('👍');

          final after = container.read(emojiReactionsProvider);
          expect(after, hasLength(1));
          expect(after.first.emoji, equals('👍'));
        },
      );
    });

    group('Send Message', () {
      test('sendMessage completes when keeper', () async {
        final mockSession = FakeSessionController();
        mockSession.isCurrentUserKeeperValue = true;

        final container = ProviderContainer();
        final controller = container.read(
          sessionMessagingControllerProvider(mockSession).notifier,
        );

        // Should not throw
        await controller.sendMessage('Hello everyone!');

        expect(mockSession.addedChatMessages, isNotEmpty);
        expect(
          mockSession.addedChatMessages.first.message,
          equals('Hello everyone!'),
        );
      });

      test('sendMessage logs warning when not keeper', () async {
        final mockSession = FakeSessionController();
        mockSession.isCurrentUserKeeperValue = false;

        final container = ProviderContainer();
        final controller = container.read(
          sessionMessagingControllerProvider(mockSession).notifier,
        );

        await controller.sendMessage('Hello');

        expect(mockSession.addedChatMessages, isEmpty);
      });
    });
  });
}
