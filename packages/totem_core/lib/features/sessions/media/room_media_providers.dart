import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_core/features/sessions/media/room_media.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';

part 'room_media_providers.g.dart';

/// Media for the current session's room, or null outside a session.
@Riverpod(dependencies: [currentSession])
RoomMedia? roomMedia(Ref ref) => ref.watch(currentSessionProvider)?.roomMedia;

/// A participant's media state. Starts from the current state, so the first
/// frame is already correct, then follows every change.
@Riverpod(dependencies: [roomMedia])
class ParticipantMedia extends _$ParticipantMedia {
  @override
  ParticipantMediaState build(String identity) {
    final media = ref.watch(roomMediaProvider);
    if (media == null) return ParticipantMediaState.none;
    final subscription = media.watch(identity).listen((next) => state = next);
    ref.onDispose(subscription.cancel);
    return media.stateOf(identity);
  }
}
