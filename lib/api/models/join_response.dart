// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'join_response.g.dart';

/// Token for connecting to a LiveKit room.
@JsonSerializable()
class JoinResponse {
  const JoinResponse({
    required this.token,
    required this.isAlreadyPresent,
  });

  factory JoinResponse.fromJson(Map<String, Object?> json) =>
      _$JoinResponseFromJson(json);

  final String token;
  @JsonKey(name: 'is_already_present')
  final bool isAlreadyPresent;

  Map<String, Object?> toJson() => _$JoinResponseToJson(this);
}
