import 'package:totem_core/features/sessions/media/participant_info.dart';

ParticipantInfo testParticipant(
  String identity, {
  String? name,
  bool isLocal = false,
}) => ParticipantInfo(
  sid: identity,
  identity: identity,
  name: name ?? identity,
  isLocal: isLocal,
);
