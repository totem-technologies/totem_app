// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import

import 'package:dio/dio.dart';

import 'fallback/fallback_client.dart';
import 'spaces/spaces_client.dart';
import 'blog/blog_client.dart';
import 'meetings/meetings_client.dart';

/// Totem Mobile API `v1`.
///
///
class MobileTotemApi {
  MobileTotemApi(
    Dio dio, {
    String? baseUrl,
  }) : _dio = dio,
       _baseUrl = baseUrl;

  final Dio _dio;
  final String? _baseUrl;

  static String get version => '1';

  FallbackClient? _fallback;
  SpacesClient? _spaces;
  BlogClient? _blog;
  MeetingsClient? _meetings;

  FallbackClient get fallback =>
      _fallback ??= FallbackClient(_dio, baseUrl: _baseUrl);

  SpacesClient get spaces => _spaces ??= SpacesClient(_dio, baseUrl: _baseUrl);

  BlogClient get blog => _blog ??= BlogClient(_dio, baseUrl: _baseUrl);

  MeetingsClient get meetings =>
      _meetings ??= MeetingsClient(_dio, baseUrl: _baseUrl);
}
