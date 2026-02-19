// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'pass_stick_event.g.dart';

@JsonSerializable()
class PassStickEvent {
  const PassStickEvent({
    this.type = 'pass_stick',
  });

  factory PassStickEvent.fromJson(Map<String, Object?> json) =>
      _$PassStickEventFromJson(json);

  final String type;

  Map<String, Object?> toJson() => _$PassStickEventToJson(this);
}
