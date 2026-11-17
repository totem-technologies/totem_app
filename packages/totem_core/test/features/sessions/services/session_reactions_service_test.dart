import 'dart:async';
import 'dart:convert';

import 'package:checks/checks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/features/sessions/media/participant_info.dart';
import 'package:totem_core/features/sessions/providers/emoji_reactions_provider.dart';
import 'package:totem_core/features/sessions/services/session_packet_router.dart';
import 'package:totem_core/features/sessions/services/session_reactions_service.dart';
import 'package:totem_core/features/sessions/transport/session_transport.dart';

import '../transport/fake_session_transport.dart';

const _sender = ParticipantInfo(
  sid: 'sender',
  identity: 'sender',
  name: 'Sender',
);
const _other = ParticipantInfo(sid: 'other', identity: 'other', name: 'Other');

SessionTransportPacket _reaction({
  ParticipantInfo? sender = _sender,
  String emoji = '👍',
  String topic = 'lk-emoji-topic',
}) => SessionTransportPacket(
  bytes: utf8.encode(emoji),
  topic: topic,
  sender: sender,
);

class _Harness {
  _Harness() {
    container = ProviderContainer(
      overrides: [emojiReactionClockProvider.overrideWithValue(() => now)],
    );
    connection = FakeSessionTransport()
      ..localIdentity = 'local'
      ..connectionState = SessionTransportConnectionState.connected;
    service = SessionReactionsService(
      transport: () => connection,
      hasKeeper: () => keeperPresent,
      emit: (identity, emoji) {
        // Run the real throttle and update before optionally holding completion.
        final emitted = container
            .read(emojiReactionsProvider.notifier)
            .emitIncomingReaction(identity, emoji);
        if (emitCompletion case final completion?) {
          emitStarted?.complete();
          return completion.future.then((_) => emitted);
        }
        return emitted;
      },
      onError: (error, _) => errors.add(error),
    );
  }
  late final ProviderContainer container;
  late final SessionReactionsService service;
  late FakeSessionTransport connection;
  DateTime now = DateTime.utc(2026);
  bool keeperPresent = true;
  final errors = <Object>[];
  Completer<void>? emitStarted;
  Completer<void>? emitCompletion;
  List<SessionEmojiReaction> get reactions =>
      container.read(emojiReactionsProvider);

  Future<void> dispose() async {
    service.dispose();
    container.dispose();
    await connection.dispose();
  }
}

void main() {
  test(
    'incoming packets use the real per-participant reaction throttle',
    () async {
      final h = _Harness();
      addTearDown(h.dispose);
      h.service
        ..receive(_reaction())
        ..receive(_reaction())
        ..receive(_reaction(emoji: '❤️'))
        ..receive(_reaction(sender: _other, emoji: '🔥'));

      check(
        h.reactions.map((reaction) => (reaction.userIdentity, reaction.emoji)),
      ).deepEquals([('sender', '👍'), ('other', '🔥')]);
      h.now = h.now.add(const Duration(milliseconds: 310));
      h.service.receive(_reaction(emoji: '❤️'));
      check(
        h.reactions.map((reaction) => reaction.emoji),
      ).deepEquals(['👍', '🔥', '❤️']);
      check(h.connection.publications).isEmpty();
    },
  );

  test(
    'wrong topics and unknown senders do not reach reaction state',
    () async {
      final h = _Harness();
      addTearDown(h.dispose);
      h.service
        ..receive(_reaction(topic: 'lk-chat-topic'))
        ..receive(_reaction(topic: 'totem.admission.v1'))
        ..receive(_reaction(sender: null));

      check(h.reactions).isEmpty();
      check(h.connection.publications).isEmpty();
      check(h.errors).isEmpty();
    },
  );

  test(
    'malformed incoming reaction bytes are reported without adding a reaction',
    () async {
      final h = _Harness();
      addTearDown(h.dispose);
      h.service.receive(
        SessionTransportPacket(
          bytes: [0xff],
          topic: SessionCommunicationTopics.emoji.topic,
          sender: _sender,
        ),
      );

      check(h.reactions).isEmpty();
      check(h.errors).length.equals(1);
      check(h.connection.publications).isEmpty();
    },
  );

  test(
    'outgoing reactions are emitted locally once and only accepted reactions publish',
    () async {
      final h = _Harness();
      addTearDown(h.dispose);

      await h.service.send('👍');
      await h.service.send('❤️');

      check(h.reactions).length.equals(1);
      check(h.reactions.single.userIdentity).equals('local');
      check(h.reactions.single.emoji).equals('👍');
      check(h.connection.publications).length.equals(1);
      final packet = h.connection.publications.single;
      check(packet.topic).equals(SessionCommunicationTopics.emoji.topic);
      check(utf8.decode(packet.bytes)).equals('👍');
      check(packet.reliable).isFalse();
      check(packet.recipients).isEmpty();

      h.now = h.now.add(const Duration(milliseconds: 310));
      await h.service.send('❤️');
      check(h.connection.publications).length.equals(2);
      check(
        h.reactions.map((reaction) => reaction.emoji),
      ).deepEquals(['👍', '❤️']);
    },
  );

  test(
    'missing Keeper or disconnected transport prevents local and remote emission',
    () async {
      final h = _Harness();
      addTearDown(h.dispose);
      h.keeperPresent = false;
      await h.service.send('👍');
      h.keeperPresent = true;
      h.connection.connectionState =
          SessionTransportConnectionState.disconnected;
      await h.service.send('👍');

      check(h.reactions).isEmpty();
      check(h.connection.publications).isEmpty();
    },
  );

  test(
    'failed publication reports its error without undoing accepted local feedback',
    () async {
      final h = _Harness();
      addTearDown(h.dispose);
      final failure = Exception('reaction publication failed');
      h.connection.publishFailure = failure;

      await h.service.send('👍');

      check(h.errors.single).identicalTo(failure);
      check(h.reactions).length.equals(1);
      check(h.connection.publications).isEmpty();
    },
  );

  for (final end in ['cancel', 'replace', 'dispose']) {
    test('async local emission cannot publish after $end', () async {
      final h = _Harness();
      addTearDown(h.dispose);
      h
        ..emitStarted = Completer<void>()
        ..emitCompletion = Completer<void>();
      final oldConnection = h.connection;
      final sending = h.service.send('👍');
      await h.emitStarted!.future;
      check(h.reactions).length.equals(1);
      switch (end) {
        case 'cancel':
          h.service.cancelPending();
        case 'replace':
          h.connection = FakeSessionTransport()
            ..connectionState = SessionTransportConnectionState.connected;
        case 'dispose':
          h.service.dispose();
      }
      h.emitCompletion!.complete();
      await sending;

      check(oldConnection.publications).isEmpty();
      check(h.connection.publications).isEmpty();
      check(h.errors).isEmpty();
      if (end == 'replace') await oldConnection.dispose();
    });
  }
}
