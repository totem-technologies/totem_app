// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'active_detail.g.dart';

@JsonSerializable()
class ActiveDetail {
  const ActiveDetail({
    this.type = 'active',
  });

  factory ActiveDetail.fromJson(Map<String, Object?> json) =>
      _$ActiveDetailFromJson(json);

  final String type;

  Map<String, Object?> toJson() => _$ActiveDetailToJson(this);
}
