// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'accept_stick_event.g.dart';

@JsonSerializable()
class AcceptStickEvent {
  const AcceptStickEvent({
    this.type = 'accept_stick',
  });

  factory AcceptStickEvent.fromJson(Map<String, Object?> json) =>
      _$AcceptStickEventFromJson(json);

  final String type;

  Map<String, Object?> toJson() => _$AcceptStickEventToJson(this);
}
