import 'package:flutter_test/flutter_test.dart';
import 'package:totem_app/api/models/session_state.dart';
import 'package:totem_app/api/models/session_status.dart';

void main() {
  group('SessionState Tests', () {
    group('fromJson and toJson', () {
      test('should serialize and deserialize correctly', () {
        const originalState = SessionState(
          keeperSlug: 'user123',
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
          'speaking_order': <String>[],
        };

        final state = SessionState.fromJson(json);

        expect(state.status, equals(SessionStatus.waiting));
        expect(state.speakingNow, isNull);
        expect(state.speakingOrder, isEmpty);
      });

      test('should handle all session statuses', () {
        for (final status in SessionStatus.values) {
          final state = SessionState(
            keeperSlug: 'test_user',
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
          keeperSlug: 'user123',
          status: SessionStatus.started,
          speakingNow: 'user123',
          speakingOrder: ['user123', 'user456'],
        );

        const state2 = SessionState(
          keeperSlug: 'user123',
          status: SessionStatus.started,
          speakingNow: 'user123',
          speakingOrder: ['user123', 'user456'],
        );

        expect(state1, equals(state2));
        expect(state1.hashCode, equals(state2.hashCode));
      });

      test('should not be equal for different statuses', () {
        const state1 = SessionState(
          keeperSlug: 'user123',
          status: SessionStatus.started,
          speakingNow: 'user123',
          speakingOrder: ['user123'],
        );

        const state2 = SessionState(
          keeperSlug: 'user123',
          status: SessionStatus.ended,
          speakingNow: 'user123',
          speakingOrder: ['user123'],
        );

        expect(state1, isNot(equals(state2)));
      });

      test('should not be equal for different speakingNow', () {
        const state1 = SessionState(
          keeperSlug: 'user123',
          status: SessionStatus.started,
          speakingNow: 'user123',
          speakingOrder: ['user123'],
        );

        const state2 = SessionState(
          keeperSlug: 'user123',
          status: SessionStatus.started,
          speakingNow: 'user456',
          speakingOrder: ['user123'],
        );

        expect(state1, isNot(equals(state2)));
      });

      test('should not be equal for different speakingOrder', () {
        const state1 = SessionState(
          keeperSlug: 'user123',
          status: SessionStatus.started,
          speakingNow: 'user123',
          speakingOrder: ['user123', 'user456'],
        );

        const state2 = SessionState(
          keeperSlug: 'user123',
          status: SessionStatus.started,
          speakingNow: 'user123',
          speakingOrder: ['user456', 'user123'],
        );

        expect(state1, isNot(equals(state2)));
      });

      test('should handle null values correctly', () {
        const state1 = SessionState(
          keeperSlug: '',
          speakingOrder: [],
        );

        const state2 = SessionState(
          keeperSlug: '',
          speakingOrder: [],
        );

        expect(state1, equals(state2));
        expect(state1.hashCode, equals(state2.hashCode));
      });
    });
  });
}
