import 'package:flutter/foundation.dart';

/// User model representing an authenticated user
@immutable
class User {

  const User({
    required this.id,
    required this.email,
    required this.createdAt, this.firstName,
    this.profileImageUrl,
    this.hasCompletedOnboarding = false,
    this.isKeeper = false,
    this.lastLoginAt,
  });

  /// Factory constructor to create a User from JSON data
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      firstName: json['first_name'] as String?,
      profileImageUrl: json['profile_image_url'] as String?,
      hasCompletedOnboarding:
          json['has_completed_onboarding'] as bool? ?? false,
      isKeeper: json['is_keeper'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      lastLoginAt:
          json['last_login_at'] != null
              ? DateTime.parse(json['last_login_at'] as String)
              : null,
    );
  }
  final String id;
  final String email;
  final String? firstName;
  final String? profileImageUrl;
  final bool hasCompletedOnboarding;
  final bool isKeeper;
  final DateTime createdAt;
  final DateTime? lastLoginAt;

  /// Convert user to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'first_name': firstName,
      'profile_image_url': profileImageUrl,
      'has_completed_onboarding': hasCompletedOnboarding,
      'is_keeper': isKeeper,
      'created_at': createdAt.toIso8601String(),
      'last_login_at': lastLoginAt?.toIso8601String(),
    };
  }

  /// Create a copy of this user with modified fields
  User copyWith({
    String? firstName,
    String? profileImageUrl,
    bool? hasCompletedOnboarding,
    bool? isKeeper,
    DateTime? lastLoginAt,
  }) {
    return User(
      id: id,
      email: email,
      firstName: firstName ?? this.firstName,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      isKeeper: isKeeper ?? this.isKeeper,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User &&
        other.id == id &&
        other.email == email &&
        other.firstName == firstName &&
        other.profileImageUrl == profileImageUrl &&
        other.hasCompletedOnboarding == hasCompletedOnboarding &&
        other.isKeeper == isKeeper &&
        other.createdAt == createdAt &&
        other.lastLoginAt == lastLoginAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        email.hashCode ^
        firstName.hashCode ^
        profileImageUrl.hashCode ^
        hasCompletedOnboarding.hashCode ^
        isKeeper.hashCode ^
        createdAt.hashCode ^
        lastLoginAt.hashCode;
  }
}

/// Auth response model for login operations
class AuthResponse {

  AuthResponse({required this.user, required this.apiKey});

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      user: User.fromJson(json['user'] as Map<String, dynamic>),
      apiKey: json['api_key'] as String,
    );
  }
  final User user;
  final String apiKey;
}
