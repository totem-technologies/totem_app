// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/message_response.dart';
import '../models/pin_request_schema.dart';
import '../models/refresh_token_schema.dart';
import '../models/token_response.dart';
import '../models/user_schema.dart';
import '../models/validate_pin_schema.dart';

part 'client_client.g.dart';

@RestApi()
abstract class ClientClient {
  factory ClientClient(Dio dio, {String? baseUrl}) = _ClientClient;

  /// Current User
  @GET('/api/mobile/protected/currentuser')
  Future<UserSchema> totemApiMobileApiCurrentUser();

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
