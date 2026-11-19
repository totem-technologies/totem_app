import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:totem_core/features/sessions/models/session_emoji_reaction.dart';
import 'package:uuid/uuid.dart';

/// Entry-owned reaction state. Presentation projects this buffer; another
/// session's cleanup and rate limits cannot affect it.
class SessionReactionBuffer extends ChangeNotifier {
  SessionReactionBuffer({DateTime Function()? now, String Function()? createId})
    : _now = now ?? DateTime.timestamp,
      _createId = createId ?? const Uuid().v1;
  final DateTime Function() _now;
  final String Function() _createId;
  List<SessionEmojiReaction> _reactions = const [];
  List<SessionEmojiReaction> get reactions => _reactions;
  bool _disposed = false;

  Future<bool> emitIncomingReaction(String identity, String emoji) async {
    if (_disposed) return false;
    final now = _now();
    final last = _reactions
        .lastWhereOrNull((r) => r.userIdentity == identity)
        ?.timestamp;
    if (last != null &&
        now.difference(last) < const Duration(milliseconds: 300)) {
      return false;
    }
    final next = [
      ..._reactions,
      SessionEmojiReaction(
        timestamp: now,
        userIdentity: identity,
        emoji: emoji,
        eventId: _createId(),
        displayed: false,
      ),
    ];
    if (next.length > 10) next.removeAt(0);
    _set(next);
    return true;
  }

  void markDisplayed(SessionEmojiReaction reaction) => _set([
    for (final item in _reactions)
      if (item == reaction) item.copyWith(displayed: true) else item,
  ]);
  void remove(SessionEmojiReaction reaction) =>
      _set(_reactions.where((item) => item != reaction).toList());
  void clear() => _set(const []);
  void _set(List<SessionEmojiReaction> value) {
    if (_disposed) return;
    _reactions = List.unmodifiable(value);
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    super.dispose();
  }
}
