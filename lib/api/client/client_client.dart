// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/fcm_token_register_schema.dart';
import '../models/fcm_token_response_schema.dart';
import '../models/keeper_profile_schema.dart';
import '../models/message_response.dart';
import '../models/onboard_schema.dart';
import '../models/pin_request_schema.dart';
import '../models/public_user_schema.dart';
import '../models/refresh_token_schema.dart';
import '../models/token_response.dart';
import '../models/user_schema.dart';
import '../models/user_update_schema.dart';
import '../models/validate_pin_schema.dart';

part 'client_client.g.dart';

@RestApi()
abstract class ClientClient {
  factory ClientClient(Dio dio, {String? baseUrl}) = _ClientClient;

  /// Register Fcm Token.
  ///
  /// Register or update an FCM token for the current user.
  @POST('/api/mobile/protected/fcm/register')
  Future<FcmTokenResponseSchema> totemApiMobileApiRegisterFcmToken({
    @Body() required FcmTokenRegisterSchema body,
  });

  /// Unregister Fcm Token.
  ///
  /// Mark an FCM token as inactive.
  @DELETE('/api/mobile/protected/fcm/unregister/{token}')
  Future<void> totemApiMobileApiUnregisterFcmToken({
    @Path('token') required String token,
  });

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

  /// Onboard Post
  @POST('/api/mobile/protected/onboard/')
  Future<OnboardSchema> totemOnboardMobileApiOnboardPost({
    @Body() required OnboardSchema body,
  });

  /// Onboard Get
  @GET('/api/mobile/protected/onboard/')
  Future<OnboardSchema> totemOnboardMobileApiOnboardGet();

  /// Subscribe To Space
  @POST('/api/mobile/protected/spaces/subscribe/{space_slug}')
  Future<bool> totemCirclesMobileApiSubscribeToSpace({
    @Path('space_slug') required String spaceSlug,
  });

  /// Unsubscribe To Space
  @DELETE('/api/mobile/protected/spaces/subscribe/{space_slug}')
  Future<bool> totemCirclesMobileApiUnsubscribeToSpace({
    @Path('space_slug') required String spaceSlug,
  });

  /// List Subscriptions
  @GET('/api/mobile/protected/spaces/subscribe')
  Future<bool> totemCirclesMobileApiListSubscriptions();

  /// Request Pin.
  ///
  /// Request a PIN code to be sent via email.
  /// This endpoint handles both new and existing users.
  @POST('/api/mobile/auth/request-pin')
  Future<MessageResponse> totemApiAuthRequestPin({
    @Body() required PinRequestSchema body,
  });

  /// Validate Pin.
  ///
  /// Validate PIN and issue token pair.
  @POST('/api/mobile/auth/validate-pin')
  Future<TokenResponse> totemApiAuthValidatePin({
    @Body() required ValidatePinSchema body,
  });

  /// Refresh Token.
  ///
  /// Refresh access token using a valid refresh token.
  @POST('/api/mobile/auth/refresh')
  Future<TokenResponse> totemApiAuthRefreshToken({
    @Body() required RefreshTokenSchema body,
  });

  /// Logout.
  ///
  /// Logout by invalidating a refresh token.
  @POST('/api/mobile/auth/logout')
  Future<MessageResponse> totemApiAuthLogout({
    @Body() required RefreshTokenSchema body,
  });
}
