// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'onboard_schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OnboardSchema _$OnboardSchemaFromJson(Map<String, dynamic> json) =>
    OnboardSchema(
      referralOther: json['referral_other'] as String? ?? '',
      yearBorn: (json['year_born'] as num?)?.toInt(),
      hopes: json['hopes'] as String?,
      referralSource:
          json['referral_source'] == null
              ? ReferralChoices.valueDefault
              : ReferralChoices.fromJson(json['referral_source'] as String),
    );

Map<String, dynamic> _$OnboardSchemaToJson(OnboardSchema instance) =>
    <String, dynamic>{
      'referral_source': _$ReferralChoicesEnumMap[instance.referralSource]!,
      'year_born': instance.yearBorn,
      'hopes': instance.hopes,
      'referral_other': instance.referralOther,
    };

const _$ReferralChoicesEnumMap = {
  ReferralChoices.valueDefault: 'default',
  ReferralChoices.search: 'search',
  ReferralChoices.social: 'social',
  ReferralChoices.keeper: 'keeper',
  ReferralChoices.pamphlet: 'pamphlet',
  ReferralChoices.blog: 'blog',
  ReferralChoices.newsletter: 'newsletter',
  ReferralChoices.dream: 'dream',
  ReferralChoices.other: 'other',
  ReferralChoices.$unknown: r'$unknown',
};
