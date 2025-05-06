// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import

import 'package:json_annotation/json_annotation.dart';

part 'message_response.g.dart';

@JsonSerializable()
class MessageResponse {
  const MessageResponse({
    required this.message,
  });
  
  factory MessageResponse.fromJson(Map<String, Object?> json) => _$MessageResponseFromJson(json);
  
  final String message;

  Map<String, Object?> toJson() => _$MessageResponseToJson(this);
}
