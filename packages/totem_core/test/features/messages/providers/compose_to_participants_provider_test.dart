import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/features/messages/providers/compose_to_participants_provider.dart';

void main() {
  group('ComposeToParticipantsNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() => container.dispose());

    test('toggleRecipient adds and removes an id', () {
      final notifier = container.read(
        composeToParticipantsProvider('session-1').notifier,
      )..seedRecipients(['a', 'b', 'c']);
      expect(
        container.read(composeToParticipantsProvider('session-1')).selected,
        {'a', 'b', 'c'},
      );

      notifier.toggleRecipient('b');
      expect(
        container.read(composeToParticipantsProvider('session-1')).selected,
        {'a', 'c'},
      );

      notifier.toggleRecipient('b');
      expect(
        container.read(composeToParticipantsProvider('session-1')).selected,
        {'a', 'b', 'c'},
      );
    });

    test('seedRecipients is a no-op after the first call', () {
      container.read(composeToParticipantsProvider('session-1').notifier)
        ..seedRecipients(['a', 'b'])
        ..toggleRecipient('a')
        ..seedRecipients(['a', 'b', 'c']);

      expect(
        container.read(composeToParticipantsProvider('session-1')).selected,
        {'b'},
      );
    });

    test('families are isolated by session slug', () {
      container
          .read(composeToParticipantsProvider('session-a').notifier)
          .seedRecipients(['a']);
      container
          .read(composeToParticipantsProvider('session-b').notifier)
          .seedRecipients(['b']);

      expect(
        container.read(composeToParticipantsProvider('session-a')).selected,
        {'a'},
      );
      expect(
        container.read(composeToParticipantsProvider('session-b')).selected,
        {'b'},
      );
    });
  });
}
