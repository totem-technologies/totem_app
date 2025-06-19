// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import

import 'package:dio/dio.dart';

import 'client/client_client.dart';
import 'events/events_client.dart';
import 'spaces/spaces_client.dart';

/// Totem API `v1`.
///
///
class TotemApi {
  TotemApi(
    Dio dio, {
    String? baseUrl,
  }) : _dio = dio,
       _baseUrl = baseUrl;

  final Dio _dio;
  final String? _baseUrl;

  static String get version => '1';

  ClientClient? _client;
  EventsClient? _events;
  SpacesClient? _spaces;

  ClientClient get client => _client ??= ClientClient(_dio, baseUrl: _baseUrl);

  EventsClient get events => _events ??= EventsClient(_dio, baseUrl: _baseUrl);

  SpacesClient get spaces => _spaces ??= SpacesClient(_dio, baseUrl: _baseUrl);
}
