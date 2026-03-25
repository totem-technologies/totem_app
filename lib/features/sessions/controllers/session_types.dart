import 'package:livekit_client/livekit_client.dart';
import 'package:totem_app/core/api/lib/totem_mobile_api.dart';

export 'package:flutter/foundation.dart' show AsyncCallback, VoidCallback;

typedef BoolGetter = bool Function();

typedef CurrentRoomGetter = Room? Function();
typedef RoomStateGetter = RoomState Function();

typedef BoolCallback = void Function(bool value);

typedef DisconnectReasonCallback = void Function(DisconnectReason? reason);
typedef DataReceivedEventCallback = void Function(DataReceivedEvent event);
typedef ParticipantDisconnectedEventCallback =
    void Function(ParticipantDisconnectedEvent event);
typedef ParticipantConnectedEventCallback =
    void Function(ParticipantConnectedEvent event);
