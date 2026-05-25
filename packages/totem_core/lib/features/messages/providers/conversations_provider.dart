import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_core/features/messages/repositories/messages_repository.dart';

import '../models/conversation.dart';

part 'conversations_provider.g.dart';

@riverpod
Future<List<Conversation>> conversations(Ref ref) =>
    ref.watch(messagesRepositoryProvider).getConversations();
