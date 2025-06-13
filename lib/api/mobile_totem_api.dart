// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import

import 'package:dio/dio.dart';

import 'client/client_client.dart';
import 'blog/blog_client.dart';

/// Totem Mobile API `v1`.
///
///
class MobileTotemApi {
  MobileTotemApi(Dio dio, {String? baseUrl}) : _dio = dio, _baseUrl = baseUrl;

  final Dio _dio;
  final String? _baseUrl;

  static String get version => '1';

  ClientClient? _client;
  BlogClient? _blog;

  ClientClient get client => _client ??= ClientClient(_dio, baseUrl: _baseUrl);

  BlogClient get blog => _blog ??= BlogClient(_dio, baseUrl: _baseUrl);
}
