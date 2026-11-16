import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/features/sessions/repositories/session_repository.dart';
import 'package:totem_core/features/sessions/services/session_commands.dart';

/// Riverpod/backend boundary. Feature command services receive this explicitly.
class SessionCommandBackend
    implements SessionTurnBackend, SessionModerationBackend {
  SessionCommandBackend(this.ref, this.slug);
  final Ref ref;
  final String slug;
  @override
  Future<RoomState> pass(
    int version, {
    String? customPrompt,
    int? sessionPromptId,
  }) => ref.read(
    passTotemProvider(
      slug,
      version,
      roundMessage: customPrompt,
      sessionPromptId: sessionPromptId,
    ).future,
  );
  @override
  Future<RoomState> accept(int version) =>
      ref.read(acceptTotemProvider(slug, version).future);
  @override
  Future<RoomState> reorder(int version, List<String> order) =>
      ref.read(reorderParticipantsProvider(slug, order, version).future);
  @override
  Future<RoomState> forcePass(int version) =>
      ref.read(forcePassTotemProvider(slug, version).future);
  @override
  Future<RoomState> start(int version, {String? prompt}) =>
      ref.read(startSessionProvider(slug, version, prompt: prompt).future);
  @override
  Future<RoomState> end(int version) =>
      ref.read(endSessionProvider(slug, version).future);
  @override
  Future<RoomState> setPrompt(
    int version, {
    String? customPrompt,
    int? sessionPromptId,
    bool clearPrompt = false,
  }) => ref.read(
    setSessionPromptProvider(
      slug,
      version,
      customPrompt: customPrompt,
      sessionPromptId: sessionPromptId,
      clearPrompt: clearPrompt,
    ).future,
  );
  @override
  Future<void> remove(String identity) =>
      ref.read(removeParticipantProvider(slug, identity).future);
  @override
  Future<RoomState> ban(int version, String identity) =>
      ref.read(banParticipantProvider(slug, identity, version).future);
  @override
  Future<RoomState> unban(int version, String identity) =>
      ref.read(unbanParticipantProvider(slug, identity, version).future);
  @override
  Future<void> mute(String identity) =>
      ref.read(muteParticipantProvider(slug, identity).future);
  @override
  Future<void> disableCamera(String identity) =>
      ref.read(disableParticipantCameraProvider(slug, identity).future);
  @override
  Future<void> muteEveryone() => ref.read(muteEveryoneProvider(slug).future);
}
