// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'end_reason.dart';

part 'ended_detail.g.dart';

@JsonSerializable()
class EndedDetail {
  const EndedDetail({
    required this.reason,
    this.type = 'ended',
  });

  factory EndedDetail.fromJson(Map<String, Object?> json) =>
      _$EndedDetailFromJson(json);

  final String type;
  final EndReason reason;

  Map<String, Object?> toJson() => _$EndedDetailToJson(this);
}
