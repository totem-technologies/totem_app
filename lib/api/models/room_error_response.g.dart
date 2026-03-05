// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'room_error_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RoomErrorResponse _$RoomErrorResponseFromJson(Map<String, dynamic> json) =>
    RoomErrorResponse(
      code: ErrorCode.fromJson(json['code'] as String),
      message: json['message'] as String,
      detail: json['detail'] as String?,
    );

Map<String, dynamic> _$RoomErrorResponseToJson(RoomErrorResponse instance) =>
    <String, dynamic>{
      'code': _$ErrorCodeEnumMap[instance.code]!,
      'message': instance.message,
      'detail': instance.detail,
    };

const _$ErrorCodeEnumMap = {
  ErrorCode.notInRoom: 'not_in_room',
  ErrorCode.notKeeper: 'not_keeper',
  ErrorCode.notCurrentSpeaker: 'not_current_speaker',
  ErrorCode.notNextSpeaker: 'not_next_speaker',
  ErrorCode.banned: 'banned',
  ErrorCode.invalidTransition: 'invalid_transition',
  ErrorCode.roomNotActive: 'room_not_active',
  ErrorCode.roomNotWaiting: 'room_not_waiting',
  ErrorCode.roomAlreadyEnded: 'room_already_ended',
  ErrorCode.invalidParticipantOrder: 'invalid_participant_order',
  ErrorCode.staleVersion: 'stale_version',
  ErrorCode.notJoinable: 'not_joinable',
  ErrorCode.livekitError: 'livekit_error',
  ErrorCode.notFound: 'not_found',
  ErrorCode.$unknown: r'$unknown',
};
