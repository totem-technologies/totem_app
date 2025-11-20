// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'mobile_space_detail_schema.dart';

part 'paged_mobile_space_detail_schema.g.dart';

@JsonSerializable()
class PagedMobileSpaceDetailSchema {
  const PagedMobileSpaceDetailSchema({
    required this.items,
    required this.count,
  });

  factory PagedMobileSpaceDetailSchema.fromJson(Map<String, Object?> json) =>
      _$PagedMobileSpaceDetailSchemaFromJson(json);

  final List<MobileSpaceDetailSchema> items;
  final int count;

  Map<String, Object?> toJson() => _$PagedMobileSpaceDetailSchemaToJson(this);
}
