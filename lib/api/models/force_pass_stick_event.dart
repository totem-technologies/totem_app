// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'force_pass_stick_event.g.dart';

/// Keeper forces the current speaker to pass the stick.
/// The next speaker won't have a chance to accept — the stick will be passed immediately.
@JsonSerializable()
class ForcePassStickEvent {
  const ForcePassStickEvent({
    this.type = 'force_pass_stick',
  });

  factory ForcePassStickEvent.fromJson(Map<String, Object?> json) =>
      _$ForcePassStickEventFromJson(json);

  final String type;

  Map<String, Object?> toJson() => _$ForcePassStickEventToJson(this);
}
