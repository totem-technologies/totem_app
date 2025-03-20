// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/avatar_update.dart';
import '../models/login_out.dart';
import '../models/token_out.dart';
import '../models/user_schema.dart';

part 'client_client.g.dart';

@RestApi()
abstract class ClientClient {
  factory ClientClient(Dio dio, {String? baseUrl}) = _ClientClient;

  /// Secret
  @GET('/api/v1/protected')
  Future<void> totemApiApiSecret();

  /// Login
  @POST('/api/v1/auth/login')
  Future<LoginOut> totemApiApiLogin({
    @Query('email') required String email,
  });

  /// Token
  @POST('/api/v1/auth/token')
  Future<TokenOut> totemApiApiToken({
    @Query('token') required String token,
  });

  /// Current User
  @GET('/api/v1/auth/currentuser')
  Future<UserSchema> totemApiApiCurrentUser();

  /// User Avatar Update
  @POST('/api/v1/user/avatarupdate')
  Future<void> totemApiApiUserAvatarUpdate({
    @Body() required AvatarUpdate body,
  });

  /// User Upload Profile Image
  @MultiPart()
  @POST('/api/v1/user/avatarimage')
  Future<void> totemApiApiUserUploadProfileImage({
    @Part(name: 'file') required File file,
  });
}
