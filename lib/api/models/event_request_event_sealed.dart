// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'accept_stick_event.dart';
import 'ban_participant_event.dart';
import 'end_reason.dart';
import 'end_room_event.dart';
import 'force_pass_stick_event.dart';
import 'pass_stick_event.dart';
import 'reorder_event.dart';
import 'start_room_event.dart';
import 'unban_participant_event.dart';

part 'event_request_event_sealed.g.dart';

@JsonSerializable(createFactory: false)
sealed class EventRequestEventSealed {
  const EventRequestEventSealed();

  factory EventRequestEventSealed.fromJson(Map<String, dynamic> json) =>
      EventRequestEventSealedDeserializer.tryDeserialize(json);

  Map<String, dynamic> toJson();
}

extension EventRequestEventSealedDeserializer on EventRequestEventSealed {
  static EventRequestEventSealed tryDeserialize(
    Map<String, dynamic> json, {
    String key = 'type',
    Map<Type, Object?>? mapping,
  }) {
    final mappingFallback = const <Type, Object?>{
      EventRequestEventSealedAcceptStickEvent: 'accept_stick',
      EventRequestEventSealedBanParticipantEvent: 'ban_participant',
      EventRequestEventSealedEndRoomEvent: 'end_room',
      EventRequestEventSealedForcePassStickEvent: 'force_pass_stick',
      EventRequestEventSealedPassStickEvent: 'pass_stick',
      EventRequestEventSealedReorderEvent: 'reorder',
      EventRequestEventSealedStartRoomEvent: 'start_room',
      EventRequestEventSealedUnbanParticipantEvent: 'unban_participant',
    };
    final value = json[key];
    final effective = mapping ?? mappingFallback;
    return switch (value) {
      _ when value == effective[EventRequestEventSealedAcceptStickEvent] =>
        EventRequestEventSealedAcceptStickEvent.fromJson(json),
      _ when value == effective[EventRequestEventSealedBanParticipantEvent] =>
        EventRequestEventSealedBanParticipantEvent.fromJson(json),
      _ when value == effective[EventRequestEventSealedEndRoomEvent] =>
        EventRequestEventSealedEndRoomEvent.fromJson(json),
      _ when value == effective[EventRequestEventSealedForcePassStickEvent] =>
        EventRequestEventSealedForcePassStickEvent.fromJson(json),
      _ when value == effective[EventRequestEventSealedPassStickEvent] =>
        EventRequestEventSealedPassStickEvent.fromJson(json),
      _ when value == effective[EventRequestEventSealedReorderEvent] =>
        EventRequestEventSealedReorderEvent.fromJson(json),
      _ when value == effective[EventRequestEventSealedStartRoomEvent] =>
        EventRequestEventSealedStartRoomEvent.fromJson(json),
      _ when value == effective[EventRequestEventSealedUnbanParticipantEvent] =>
        EventRequestEventSealedUnbanParticipantEvent.fromJson(json),
      _ => throw FormatException(
        'Unknown discriminator value "${json[key]}" for EventRequestEventSealed',
      ),
    };
  }
}

@JsonSerializable()
class EventRequestEventSealedAcceptStickEvent extends EventRequestEventSealed
    implements AcceptStickEvent {
  @override
  final String type;

  const EventRequestEventSealedAcceptStickEvent({
    required this.type,
  });

  factory EventRequestEventSealedAcceptStickEvent.fromJson(
    Map<String, dynamic> json,
  ) => _$EventRequestEventSealedAcceptStickEventFromJson(json);

  @override
  Map<String, dynamic> toJson() =>
      _$EventRequestEventSealedAcceptStickEventToJson(this);
}

@JsonSerializable()
class EventRequestEventSealedBanParticipantEvent extends EventRequestEventSealed
    implements BanParticipantEvent {
  @override
  final String type;
  @override
  final String participantSlug;

  const EventRequestEventSealedBanParticipantEvent({
    required this.type,
    required this.participantSlug,
  });

  factory EventRequestEventSealedBanParticipantEvent.fromJson(
    Map<String, dynamic> json,
  ) => _$EventRequestEventSealedBanParticipantEventFromJson(json);

  @override
  Map<String, dynamic> toJson() =>
      _$EventRequestEventSealedBanParticipantEventToJson(this);
}

@JsonSerializable()
class EventRequestEventSealedEndRoomEvent extends EventRequestEventSealed
    implements EndRoomEvent {
  @override
  final String type;
  @override
  final EndReason reason;

  const EventRequestEventSealedEndRoomEvent({
    required this.type,
    required this.reason,
  });

  factory EventRequestEventSealedEndRoomEvent.fromJson(
    Map<String, dynamic> json,
  ) => _$EventRequestEventSealedEndRoomEventFromJson(json);

  @override
  Map<String, dynamic> toJson() =>
      _$EventRequestEventSealedEndRoomEventToJson(this);
}

@JsonSerializable()
class EventRequestEventSealedForcePassStickEvent extends EventRequestEventSealed
    implements ForcePassStickEvent {
  @override
  final String type;

  const EventRequestEventSealedForcePassStickEvent({
    required this.type,
  });

  factory EventRequestEventSealedForcePassStickEvent.fromJson(
    Map<String, dynamic> json,
  ) => _$EventRequestEventSealedForcePassStickEventFromJson(json);

  @override
  Map<String, dynamic> toJson() =>
      _$EventRequestEventSealedForcePassStickEventToJson(this);
}

@JsonSerializable()
class EventRequestEventSealedPassStickEvent extends EventRequestEventSealed
    implements PassStickEvent {
  @override
  final String type;

  const EventRequestEventSealedPassStickEvent({
    required this.type,
  });

  factory EventRequestEventSealedPassStickEvent.fromJson(
    Map<String, dynamic> json,
  ) => _$EventRequestEventSealedPassStickEventFromJson(json);

  @override
  Map<String, dynamic> toJson() =>
      _$EventRequestEventSealedPassStickEventToJson(this);
}

@JsonSerializable()
class EventRequestEventSealedReorderEvent extends EventRequestEventSealed
    implements ReorderEvent {
  @override
  final String type;
  @override
  final List<String> talkingOrder;

  const EventRequestEventSealedReorderEvent({
    required this.type,
    required this.talkingOrder,
  });

  factory EventRequestEventSealedReorderEvent.fromJson(
    Map<String, dynamic> json,
  ) => _$EventRequestEventSealedReorderEventFromJson(json);

  @override
  Map<String, dynamic> toJson() =>
      _$EventRequestEventSealedReorderEventToJson(this);
}

@JsonSerializable()
class EventRequestEventSealedStartRoomEvent extends EventRequestEventSealed
    implements StartRoomEvent {
  @override
  final String type;

  const EventRequestEventSealedStartRoomEvent({
    required this.type,
  });

  factory EventRequestEventSealedStartRoomEvent.fromJson(
    Map<String, dynamic> json,
  ) => _$EventRequestEventSealedStartRoomEventFromJson(json);

  @override
  Map<String, dynamic> toJson() =>
      _$EventRequestEventSealedStartRoomEventToJson(this);
}

@JsonSerializable()
class EventRequestEventSealedUnbanParticipantEvent
    extends EventRequestEventSealed
    implements UnbanParticipantEvent {
  @override
  final String type;
  @override
  final String participantSlug;

  const EventRequestEventSealedUnbanParticipantEvent({
    required this.type,
    required this.participantSlug,
  });

  factory EventRequestEventSealedUnbanParticipantEvent.fromJson(
    Map<String, dynamic> json,
  ) => _$EventRequestEventSealedUnbanParticipantEventFromJson(json);

  @override
  Map<String, dynamic> toJson() =>
      _$EventRequestEventSealedUnbanParticipantEventToJson(this);
}
