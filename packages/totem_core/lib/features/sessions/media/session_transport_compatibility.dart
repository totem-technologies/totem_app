/// Temporary SDK integrations for B1. Remove messaging conversion in B2 and
/// raw room adoption/access in C2. This file never creates a second connection.
library;

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart' as sdk;
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/features/sessions/controllers/core/join_media_owner.dart';
import 'package:totem_core/features/sessions/controllers/core/session_state.dart';
import 'package:totem_core/features/sessions/controllers/features/session_messaging_controller.dart';
import 'package:totem_core/features/sessions/media/livekit_local_media.dart';
import 'package:totem_core/features/sessions/media/livekit_room_media.dart';
import 'package:totem_core/features/sessions/media/livekit_session_transport.dart';
import 'package:totem_core/features/sessions/media/local_media.dart';
import 'package:totem_core/features/sessions/media/room_media.dart';
import 'package:totem_core/features/sessions/transport/session_transport.dart';

typedef LegacySessionRoom = sdk.Room;
typedef LegacyRoomOptions = sdk.RoomOptions;
typedef LegacyCameraOptions = sdk.CameraCaptureOptions;
typedef LegacyVideoPublishOptions = sdk.VideoPublishOptions;
const defaultCameraCaptureOptions = sdk.CameraCaptureOptions(
  params: sdk.VideoParameters(
    dimensions: sdk.VideoDimensionsPresets.h720_43,
    encoding: sdk.VideoEncoding(maxBitrate: 1300 * 1000, maxFramerate: 24),
  ),
);
sdk.VideoPublishOptions videoPublishOptionsForPlatform({
  required bool isWeb,
  required bool isWasm,
}) => sdk.VideoPublishOptions(
  videoCodec: (isWeb || isWasm) ? 'h264' : 'h265',
  backupVideoCodec: const sdk.BackupVideoCodec(codec: 'h264'),
);
sdk.RoomOptions sessionRoomOptions({
  required sdk.CameraCaptureOptions cameraOptions,
  required bool speakerEnabled,
}) => LiveKitLocalMedia.applyCapturePolicy(
  sdk.RoomOptions(
    defaultCameraCaptureOptions: cameraOptions,
    defaultAudioOutputOptions: sdk.AudioOutputOptions(
      speakerOn: speakerEnabled,
    ),
    dynacast: true,
    adaptiveStream: true,
    defaultVideoPublishOptions: videoPublishOptionsForPlatform(
      isWeb: kIsWeb,
      isWasm: kIsWasm,
    ),
  ),
);
LegacySessionRoom? legacyRoom(SessionTransport? transport) =>
    transport is LiveKitSessionTransport
    ? transport.legacyRoomForB2AndC2
    : null;
SessionTransport wrapLegacyRoom(
  LegacySessionRoom room,
  sdk.CameraCaptureOptions cameraOptions, {
  LocalMedia? localMedia,
  RoomMedia? roomMedia,
}) => LiveKitSessionTransport(
  room: room,
  cameraOptions: cameraOptions,
  localMedia: localMedia as LiveKitLocalMedia?,
  roomMedia: roomMedia as LiveKitRoomMedia?,
);
bool legacyRoomConnected(LegacySessionRoom room) =>
    room.connectionState == sdk.ConnectionState.connected;
Future<void> releaseRejectedLegacyRoom(LegacySessionRoom room) async {
  try {
    await room.disconnect();
  } catch (error, stackTrace) {
    ErrorHandler.logError(
      error,
      stackTrace: stackTrace,
      message: 'Failed to disconnect rejected session room',
    );
  }
  try {
    await room.dispose();
  } catch (error, stackTrace) {
    ErrorHandler.logError(
      error,
      stackTrace: stackTrace,
      message: 'Failed to dispose rejected session room',
    );
  }
}

sdk.LocalVideoTrack? cameraTrack(JoinMediaOwner owner) =>
    owner.track<sdk.LocalVideoTrack>();
sdk.LocalAudioTrack? microphoneTrack(JoinMediaOwner owner) =>
    owner.track<sdk.LocalAudioTrack>();
Future<bool> publishCamera(
  SessionTransport transport,
  sdk.LocalVideoTrack? track,
  sdk.VideoPublishOptions options,
) async {
  final media = transport.localMedia;
  if (media is LiveKitLocalMedia) {
    return await media.publishJoinCamera(track, publishOptions: options);
  }
  if (track != null) {
    throw StateError(
      'This media implementation cannot accept a legacy captured track',
    );
  }
  await media.setCameraEnabled(true);
  return true;
}

Future<bool> publishMicrophone(
  SessionTransport transport,
  sdk.LocalAudioTrack? track, {
  required bool muted,
}) async {
  final media = transport.localMedia;
  if (media is LiveKitLocalMedia) {
    return await media.publishJoinMicrophone(track, muted: muted);
  }
  if (track != null) {
    throw StateError(
      'This media implementation cannot accept a legacy captured track',
    );
  }
  await media.setMicrophoneEnabled(!muted);
  return true;
}

RoomError legacyCompatibleError(SessionTransportFailure failure) =>
    failure.cause is sdk.LiveKitException
    ? RoomLiveKitError(failure.cause as sdk.LiveKitException)
    : RoomTransportError(failure);
RoomDisconnectionError legacyDisconnectError(
  SessionTransportDisconnectReason reason,
) => RoomDisconnectionError(sdk.DisconnectReason.values.byName(reason.name));

/// Only the B2 legacy messaging handler needs an SDK-shaped receive event.
void deliverLegacyPacket(
  SessionMessagingController messaging,
  SessionTransportPacket packet,
  SessionTransport? transport,
) {
  if (transport is LiveKitSessionTransport) {
    final original = transport.legacyPacketForB2(packet);
    if (original != null) {
      messaging.handleDataReceived(original);
      return;
    }
  }
  throw UnsupportedError(
    'Legacy SDK messaging receive requires LiveKit until B2',
  );
}

/// C2 compatibility: retain an offered raw room without attaching its media
/// until the previous active transport has completed cleanup.
class LegacyConnectedRoomOffer {
  LegacyConnectedRoomOffer(this.room);
  final LegacySessionRoom room;
  bool _consumed = false;
  SessionTransport adopt({
    required LocalMedia localMedia,
    required RoomMedia roomMedia,
    required sdk.CameraCaptureOptions cameraOptions,
  }) {
    if (_consumed) throw StateError('Legacy room offer already consumed');
    _consumed = true;
    return wrapLegacyRoom(
      room,
      cameraOptions,
      localMedia: localMedia,
      roomMedia: roomMedia,
    );
  }

  Future<void> dispose() async {
    if (_consumed) return;
    _consumed = true;
    await releaseRejectedLegacyRoom(room);
  }
}
