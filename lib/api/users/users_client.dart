// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/feedback_schema.dart';
import '../models/keeper_profile_schema.dart';
import '../models/public_user_schema.dart';
import '../models/user_schema.dart';
import '../models/user_update_schema.dart';

part 'users_client.g.dart';

@RestApi()
abstract class UsersClient {
  factory UsersClient(Dio dio, {String? baseUrl}) = _UsersClient;

  /// Get Current User
  @GET('/api/mobile/protected/users/current')
  Future<UserSchema> totemUsersMobileApiGetCurrentUser();

  /// Get User Profile
  @GET('/api/mobile/protected/users/profile/{user_slug}')
  Future<PublicUserSchema> totemUsersMobileApiGetUserProfile({
    @Path('user_slug') required String userSlug,
  });

  /// Update Current User
  @POST('/api/mobile/protected/users/update')
  Future<UserSchema> totemUsersMobileApiUpdateCurrentUser({
    @Body() required UserUpdateSchema body,
  });

  /// Update Current User Image
  @MultiPart()
  @POST('/api/mobile/protected/users/update_image')
  Future<bool> totemUsersMobileApiUpdateCurrentUserImage({
    @Part(name: 'profile_image') required File profileImage,
  });

  /// Delete Current User
  @DELETE('/api/mobile/protected/users/delete')
  Future<bool> totemUsersMobileApiDeleteCurrentUser();

  /// Keeper
  @GET('/api/mobile/protected/users/keeper/{slug}')
  Future<KeeperProfileSchema> totemUsersMobileApiKeeper({
    @Path('slug') required String slug,
  });

  /// Submit Feedback
  @POST('/api/mobile/protected/users/feedback')
  Future<bool> totemUsersMobileApiSubmitFeedback({
    @Body() required FeedbackSchema body,
  });
}
