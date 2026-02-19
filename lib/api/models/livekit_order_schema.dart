// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'livekit_order_schema.g.dart';

@JsonSerializable()
class LivekitOrderSchema {
  const LivekitOrderSchema({
    required this.order,
  });

  factory LivekitOrderSchema.fromJson(Map<String, Object?> json) =>
      _$LivekitOrderSchemaFromJson(json);

  final List<String> order;

  Map<String, Object?> toJson() => _$LivekitOrderSchemaToJson(this);
}
