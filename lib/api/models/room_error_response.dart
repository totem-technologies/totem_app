// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'error_code.dart';

part 'room_error_response.g.dart';

/// Structured error. Clients switch on `code`, display `message`.
/// `detail` is optional extra context for debugging.
@JsonSerializable()
class RoomErrorResponse {
  const RoomErrorResponse({
    required this.code,
    required this.message,
    this.detail,
  });

  factory RoomErrorResponse.fromJson(Map<String, Object?> json) =>
      _$RoomErrorResponseFromJson(json);

  final ErrorCode code;
  final String message;
  final String? detail;

  Map<String, Object?> toJson() => _$RoomErrorResponseToJson(this);
}
