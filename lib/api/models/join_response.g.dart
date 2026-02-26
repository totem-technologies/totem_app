// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'join_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

JoinResponse _$JoinResponseFromJson(Map<String, dynamic> json) => JoinResponse(
  token: json['token'] as String,
  isAlreadyPresent: json['is_already_present'] as bool,
);

Map<String, dynamic> _$JoinResponseToJson(JoinResponse instance) =>
    <String, dynamic>{
      'token': instance.token,
      'is_already_present': instance.isAlreadyPresent,
    };
