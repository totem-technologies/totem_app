import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_core/features/sessions/media/room_media.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';

part 'room_media_providers.g.dart';

/// Media for the current session's room, or null outside a session.
@Riverpod(dependencies: [currentSession])
RoomMedia? roomMedia(Ref ref) => ref.watch(currentSessionProvider)?.roomMedia;

@Riverpod(dependencies: [roomMedia])
Stream<ParticipantMediaState> participantMediaState(Ref ref, String identity) {
  final media = ref.watch(roomMediaProvider);
  if (media == null) return Stream.value(ParticipantMediaState.none);
  return media.watch(identity);
}
