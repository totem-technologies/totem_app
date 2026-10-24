import 'package:checks/checks.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_app/features/messages/screens/messages_screen.dart';

import 'package:totem_core/features/messages/models/conversation.dart';
import 'package:totem_core/features/messages/models/message.dart';
import 'package:totem_core/features/messages/providers/conversations_provider.dart';
import 'package:totem_core/features/messages/providers/thread_provider.dart';
import 'package:totem_core/features/messages/repositories/messages_repository.dart';

class _FakeMessagesRepository implements MessagesRepository {
  _FakeMessagesRepository({this.failReads = false});

  bool failReads;
  final sent = <String>[];

  final peer = PublicUserSchema(
    profileAvatarType: ProfileAvatarTypeEnum.td,
    dateCreated: DateTime(2024),
    name: Omittable('Keeper'),
    slug: Omittable('keeper'),
    profileAvatarSeed: 'keeper-seed',
  );

  Message message(String text, {bool isOwn = false}) => Message(
    id: text,
    conversationId: 'conversation',
    senderId: isOwn ? 'me' : 'keeper',
    text: text,
    sentAt: DateTime(2024),
    isOwn: isOwn,
  );

  Conversation get conversation => Conversation(
    id: 'conversation',
    peer: peer,
    updatedAt: DateTime(2024),
    lastMessage: message('Earlier message'),
  );

  @override
  Future<List<Conversation>> getConversations() async {
    if (failReads) throw StateError('conversations unavailable');
    return [conversation];
  }

  @override
  Future<List<Message>> getMessages(
    String conversationId, {
    String? beforeId,
  }) async {
    if (failReads) throw StateError('thread unavailable');
    return [message('Earlier message')];
  }

  @override
  Future<Message> sendMessage(String conversationId, String text) async {
    sent.add(text);
    return message(text, isOwn: true);
  }

  @override
  Future<void> markAsRead(String conversationId) async {}
}

void main() {
  test(
    'conversations provider exposes repository failures and recovers on refresh',
    () async {
      final repository = _FakeMessagesRepository(failReads: true);
      final container = ProviderContainer(
        overrides: [messagesRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      await check(
        container.read(conversationsProvider.future),
      ).throws<StateError>();

      repository.failReads = false;
      check(
        await container.refresh(conversationsProvider.future),
      ).length.equals(1);
    },
  );

  test(
    'thread provider prepends a sent message and preserves loaded history',
    () async {
      final repository = _FakeMessagesRepository();
      final container = ProviderContainer(
        overrides: [messagesRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final provider = threadProvider('conversation');
      final initial = await container.read(provider.future);
      check(initial.single.text).equals('Earlier message');

      await container.read(provider.notifier).send('A reply');

      final messages = container.read(provider).requireValue;
      check(
        messages.map((message) => message.text).toList(),
      ).deepEquals(['A reply', 'Earlier message']);
      check(repository.sent).deepEquals(['A reply']);
    },
  );

  testWidgets('messages screen gives a recoverable error state', (
    tester,
  ) async {
    final repository = _FakeMessagesRepository(failReads: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [messagesRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: MessagesScreen()),
      ),
    );
    await tester.pump();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    check(
      tester.widgetList(find.text('Could not load messages.')),
    ).length.equals(1);
  });
}
