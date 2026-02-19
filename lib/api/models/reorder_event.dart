// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'reorder_event.g.dart';

/// Keeper reorders the talking order.
@JsonSerializable()
class ReorderEvent {
  const ReorderEvent({
    required this.talkingOrder,
    this.type = 'reorder',
  });

  factory ReorderEvent.fromJson(Map<String, Object?> json) =>
      _$ReorderEventFromJson(json);

  final String type;
  @JsonKey(name: 'talking_order')
  final List<String> talkingOrder;

  Map<String, Object?> toJson() => _$ReorderEventToJson(this);
}
