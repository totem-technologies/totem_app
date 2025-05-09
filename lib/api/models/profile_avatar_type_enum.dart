// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import

import 'package:json_annotation/json_annotation.dart';

@JsonEnum()
enum ProfileAvatarTypeEnum {
  @JsonValue('TD')
  tD('TD'),
  @JsonValue('IM')
  iM('IM'),

  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const ProfileAvatarTypeEnum(this.json);

  factory ProfileAvatarTypeEnum.fromJson(String json) =>
      values.firstWhere((e) => e.json == json, orElse: () => $unknown);

  final String? json;
}
