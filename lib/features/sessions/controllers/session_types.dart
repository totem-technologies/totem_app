import 'package:livekit_client/livekit_client.dart';
import 'package:totem_app/core/api/lib/totem_mobile_api.dart';

export 'package:flutter/foundation.dart' show AsyncCallback, VoidCallback;

typedef BoolGetter = bool Function();
typedef IntGetter = int Function();
typedef StringGetter = String Function();

typedef CurrentRoomGetter = Room? Function();
typedef RoomStateGetter = RoomState Function();
typedef CurrentKeeperIdentityGetter = String Function();

typedef RoomPredicate = bool Function(Room room);

typedef BoolCallback = void Function(bool value);
typedef RoomStateCallback = void Function(RoomState roomState);
typedef MessageCallback<T> = void Function(T message);

typedef DisconnectReasonCallback = void Function(DisconnectReason? reason);
typedef DataReceivedEventCallback = void Function(DataReceivedEvent event);
typedef ParticipantDisconnectedEventCallback =
    void Function(ParticipantDisconnectedEvent event);
typedef ParticipantConnectedEventCallback =
    void Function(ParticipantConnectedEvent event);
