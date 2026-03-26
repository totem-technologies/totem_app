import 'package:flutter_test/flutter_test.dart';
import 'package:totem_app/features/sessions/controllers/features/session_messaging_controller.dart';

void main() {
  group('SessionMessagingController', () {
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

    test('SessionCommunicationTopics values are distinct', () {
      final topics = SessionCommunicationTopics.values
          .map((e) => e.topic)
          .toList();

      expect(
        topics.length,
        equals(topics.toSet().length),
        reason: 'All topic values should be unique',
      );
    });
  });
}
