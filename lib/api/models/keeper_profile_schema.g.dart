// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'keeper_profile_schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

KeeperProfileSchema _$KeeperProfileSchemaFromJson(Map<String, dynamic> json) =>
    KeeperProfileSchema(
      user:
          json['user'] == null
              ? null
              : PublicUserSchema.fromJson(json['user'] as Map<String, dynamic>),
      username: json['username'] as String?,
      bio: json['bio'] as String?,
      instagramUsername: json['instagram_username'] as String?,
      website: json['website'] as String?,
      xUsername: json['x_username'] as String?,
      circleCount: (json['circle_count'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? 'Keeper',
      location: json['location'] as String? ?? 'Earth',
    );

Map<String, dynamic> _$KeeperProfileSchemaToJson(
  KeeperProfileSchema instance,
) => <String, dynamic>{
  'user': instance.user,
  'circle_count': instance.circleCount,
  'username': instance.username,
  'title': instance.title,
  'bio': instance.bio,
  'location': instance.location,
  'instagram_username': instance.instagramUsername,
  'website': instance.website,
  'x_username': instance.xUsername,
};
