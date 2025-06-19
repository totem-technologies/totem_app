// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import

import 'package:json_annotation/json_annotation.dart';

part 'message.g.dart';

@JsonSerializable()
class Message {
  const Message({
    required this.message,
  });

  factory Message.fromJson(Map<String, Object?> json) =>
      _$MessageFromJson(json);

  final String message;

  Map<String, Object?> toJson() => _$MessageToJson(this);
}
