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
  });

  factory JoinResponse.fromJson(Map<String, Object?> json) =>
      _$JoinResponseFromJson(json);

  final String token;

  Map<String, Object?> toJson() => _$JoinResponseToJson(this);
}
