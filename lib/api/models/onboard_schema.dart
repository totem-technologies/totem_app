// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'referral_choices.dart';

part 'onboard_schema.g.dart';

@JsonSerializable()
class OnboardSchema {
  const OnboardSchema({
    required this.yearBorn,
    required this.hopes,
    this.referralSource = ReferralChoices.valueDefault,
    this.referralOther = '',
  });

  factory OnboardSchema.fromJson(Map<String, Object?> json) =>
      _$OnboardSchemaFromJson(json);

  @JsonKey(name: 'referral_source')
  final ReferralChoices referralSource;
  @JsonKey(name: 'year_born')
  final int? yearBorn;
  final String? hopes;

  /// Please tell us more about how you found us
  @JsonKey(name: 'referral_other')
  final String? referralOther;

  Map<String, Object?> toJson() => _$OnboardSchemaToJson(this);
}
