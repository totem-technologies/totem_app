// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:degenerate_runtime/degenerate_runtime.dart';
import 'profile_avatar_type_enum.dart';

@immutable
final class MessagePeerSchema {
  const MessagePeerSchema({
    required this.slug,
    required this.name,
    required this.profileImage,
    required this.profileAvatarSeed,
    required this.profileAvatarType,
  });

  factory MessagePeerSchema.fromJson(Map<String, dynamic> json) {
    return MessagePeerSchema(
      slug: json['slug'] as String,
      name: json['name'] as String,
      profileImage: json['profile_image'] as String?,
      profileAvatarSeed: json['profile_avatar_seed'] as String,
      profileAvatarType: json['profile_avatar_type'] != null
          ? ProfileAvatarTypeEnum.fromJson(
              json['profile_avatar_type'] as String,
            )
          : null,
    );
  }

  final String slug;

  final String name;

  final String? profileImage;

  final String profileAvatarSeed;

  final ProfileAvatarTypeEnum? profileAvatarType;

  Map<String, dynamic> toJson() {
    return {
      'slug': slug,
      'name': name,
      'profile_image': ?profileImage,
      'profile_avatar_seed': profileAvatarSeed,
      if (profileAvatarType != null)
        'profile_avatar_type': profileAvatarType?.toJson(),
    };
  }

  static bool canParse(Map<String, dynamic> json) {
    return json.containsKey('slug') &&
        json['slug'] is String &&
        json.containsKey('name') &&
        json['name'] is String &&
        json.containsKey('profile_image') &&
        json['profile_image'] is String &&
        json.containsKey('profile_avatar_seed') &&
        json['profile_avatar_seed'] is String &&
        json.containsKey('profile_avatar_type');
  }

  MessagePeerSchema copyWith({
    String? slug,
    String? name,
    String? Function()? profileImage,
    String? profileAvatarSeed,
    ProfileAvatarTypeEnum? Function()? profileAvatarType,
  }) {
    return MessagePeerSchema(
      slug: slug ?? this.slug,
      name: name ?? this.name,
      profileImage: profileImage != null ? profileImage() : this.profileImage,
      profileAvatarSeed: profileAvatarSeed ?? this.profileAvatarSeed,
      profileAvatarType: profileAvatarType != null
          ? profileAvatarType()
          : this.profileAvatarType,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MessagePeerSchema &&
            slug == other.slug &&
            name == other.name &&
            profileImage == other.profileImage &&
            profileAvatarSeed == other.profileAvatarSeed &&
            profileAvatarType == other.profileAvatarType;
  }

  @override
  int get hashCode {
    return Object.hash(
      slug,
      name,
      profileImage,
      profileAvatarSeed,
      profileAvatarType,
    );
  }

  @override
  String toString() {
    return 'MessagePeerSchema(slug: $slug, name: $name, profileImage: $profileImage, profileAvatarSeed: $profileAvatarSeed, profileAvatarType: $profileAvatarType)';
  }
}
