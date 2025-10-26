import 'package:flutter_test/flutter_test.dart';
import 'package:totem_app/features/sessions/models/session_state.dart';

void main() {
  group('SessionState Tests', () {
    group('fromMetadata', () {
      test('should return waiting state for null metadata', () {
        final result = SessionState.fromMetadata(null);

        expect(result.status, equals(SessionStatus.waiting));
        expect(result.speakingNow, isNull);
        expect(result.speakingOrder, isEmpty);
      });

      test('should parse valid JSON metadata correctly', () {
        const validJson = '''
        {
          "status": "started",
          "speaking_now": "user123",
          "speaking_order": ["user123", "user456", "user789"]
        }
        ''';

        final result = SessionState.fromMetadata(validJson);

        expect(result.status, equals(SessionStatus.started));
        expect(result.speakingNow, equals('user123'));
        expect(result.speakingOrder, equals(['user123', 'user456', 'user789']));
      });

      test('should return waiting state for invalid JSON metadata', () {
        const invalidJson = '{"invalid": json}';

        final result = SessionState.fromMetadata(invalidJson);

        expect(result.status, equals(SessionStatus.waiting));
        expect(result.speakingNow, isNull);
        expect(result.speakingOrder, isEmpty);
      });

      test('should handle empty JSON object', () {
        const emptyJson = '{}';

        final result = SessionState.fromMetadata(emptyJson);

        expect(result.status, equals(SessionStatus.waiting));
        expect(result.speakingNow, isNull);
        expect(result.speakingOrder, isEmpty);
      });

      test('should handle partial JSON data', () {
        const partialJson = '{"status": "ended"}';

        final result = SessionState.fromMetadata(partialJson);

        expect(result.status, equals(SessionStatus.ended));
        expect(result.speakingNow, isNull);
        expect(result.speakingOrder, isNull);
      });
    });

    group('waiting constructor', () {
      test('should create correct default waiting state', () {
        const state = SessionState.waiting();

        expect(state.status, equals(SessionStatus.waiting));
        expect(state.speakingNow, isNull);
        expect(state.speakingOrder, isEmpty);
      });
    });

    group('fromJson and toJson', () {
      test('should serialize and deserialize correctly', () {
        const originalState = SessionState(
          status: SessionStatus.started,
          speakingNow: 'user123',
          speakingOrder: ['user123', 'user456'],
        );

        final json = originalState.toJson();
        final deserializedState = SessionState.fromJson(json);

        expect(deserializedState.status, equals(originalState.status));
        expect(
          deserializedState.speakingNow,
          equals(originalState.speakingNow),
        );
        expect(
          deserializedState.speakingOrder,
          equals(originalState.speakingOrder),
        );
      });

      test('should handle null speakingOrder in JSON', () {
        const json = {
          'status': 'waiting',
          'speaking_now': null,
          'speaking_order': null,
        };

        final state = SessionState.fromJson(json);

        expect(state.status, equals(SessionStatus.waiting));
        expect(state.speakingNow, isNull);
        expect(state.speakingOrder, isNull);
      });

      test('should handle all session statuses', () {
        for (final status in SessionStatus.values) {
          final state = SessionState(
            status: status,
            speakingNow: 'test_user',
            speakingOrder: const ['test_user'],
          );

          final json = state.toJson();
          final deserializedState = SessionState.fromJson(json);

          expect(deserializedState.status, equals(status));
        }
      });
    });

    group('equality and hashCode', () {
      test('should be equal for identical states', () {
        const state1 = SessionState(
          status: SessionStatus.started,
          speakingNow: 'user123',
          speakingOrder: ['user123', 'user456'],
        );

        const state2 = SessionState(
          status: SessionStatus.started,
          speakingNow: 'user123',
          speakingOrder: ['user123', 'user456'],
        );

        expect(state1, equals(state2));
        expect(state1.hashCode, equals(state2.hashCode));
      });

      test('should not be equal for different statuses', () {
        const state1 = SessionState(
          status: SessionStatus.started,
          speakingNow: 'user123',
          speakingOrder: ['user123'],
        );

        const state2 = SessionState(
          status: SessionStatus.ended,
          speakingNow: 'user123',
          speakingOrder: ['user123'],
        );

        expect(state1, isNot(equals(state2)));
      });

      test('should not be equal for different speakingNow', () {
        const state1 = SessionState(
          status: SessionStatus.started,
          speakingNow: 'user123',
          speakingOrder: ['user123'],
        );

        const state2 = SessionState(
          status: SessionStatus.started,
          speakingNow: 'user456',
          speakingOrder: ['user123'],
        );

        expect(state1, isNot(equals(state2)));
      });

      test('should not be equal for different speakingOrder', () {
        const state1 = SessionState(
          status: SessionStatus.started,
          speakingNow: 'user123',
          speakingOrder: ['user123', 'user456'],
        );

        const state2 = SessionState(
          status: SessionStatus.started,
          speakingNow: 'user123',
          speakingOrder: ['user456', 'user123'],
        );

        expect(state1, isNot(equals(state2)));
      });

      test('should handle null values correctly', () {
        const state1 = SessionState(
          status: SessionStatus.waiting,
          speakingNow: null,
          speakingOrder: null,
        );

        const state2 = SessionState(
          status: SessionStatus.waiting,
          speakingNow: null,
          speakingOrder: null,
        );

        expect(state1, equals(state2));
        expect(state1.hashCode, equals(state2.hashCode));
      });
    });

    group('toString', () {
      test('should return proper string representation', () {
        const state = SessionState(
          status: SessionStatus.started,
          speakingNow: 'user123',
          speakingOrder: ['user123', 'user456'],
        );

        final string = state.toString();

        expect(string, contains('SessionState'));
        expect(string, contains('started'));
        expect(string, contains('user123'));
        expect(string, contains('user456'));
      });
    });
  });
}
