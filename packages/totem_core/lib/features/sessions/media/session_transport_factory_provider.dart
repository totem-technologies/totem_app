import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_core/features/sessions/controllers/core/session_state.dart';
import 'package:totem_core/features/sessions/media/livekit_session_transport.dart';
import 'package:totem_core/features/sessions/media/session_transport_compatibility.dart'
    as compatibility;
import 'package:totem_core/features/sessions/transport/session_transport.dart';
part 'session_transport_factory_provider.g.dart';

@riverpod
SessionTransportFactory sessionTransportFactory(
  Ref ref,
  SessionOptions options,
) => LiveKitSessionTransportFactory(
  roomOptions: compatibility.sessionRoomOptions(
    cameraOptions: options.cameraOptions,
    speakerEnabled: options.speakerEnabled,
  ),
);
