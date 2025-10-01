// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'keeper_profile_schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

KeeperProfileSchema _$KeeperProfileSchemaFromJson(Map<String, dynamic> json) =>
    KeeperProfileSchema(
      user: PublicUserSchema.fromJson(json['user'] as Map<String, dynamic>),
      circleCount: (json['circle_count'] as num).toInt(),
      monthJoined: json['month_joined'] as String,
      title: json['title'] as String? ?? 'Keeper',
      location: json['location'] as String? ?? 'Earth',
      languages: json['languages'] as String? ?? 'English',
      bioHtml: json['bio_html'] as String?,
      username: json['username'] as String?,
      bio: json['bio'] as String?,
      instagramUsername: json['instagram_username'] as String?,
      website: json['website'] as String?,
      xUsername: json['x_username'] as String?,
      blueskyUsername: json['bluesky_username'] as String?,
    );

Map<String, dynamic> _$KeeperProfileSchemaToJson(
  KeeperProfileSchema instance,
) => <String, dynamic>{
  'user': instance.user,
  'circle_count': instance.circleCount,
  'month_joined': instance.monthJoined,
  'bio_html': instance.bioHtml,
  'username': instance.username,
  'title': instance.title,
  'bio': instance.bio,
  'location': instance.location,
  'languages': instance.languages,
  'instagram_username': instance.instagramUsername,
  'website': instance.website,
  'x_username': instance.xUsername,
  'bluesky_username': instance.blueskyUsername,
};
