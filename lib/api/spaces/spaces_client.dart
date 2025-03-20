// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/space_detail_schema.dart';

part 'spaces_client.g.dart';

@RestApi()
abstract class SpacesClient {
  factory SpacesClient(Dio dio, {String? baseUrl}) = _SpacesClient;

  /// List Spaces
  @GET('/api/v1/spaces/list')
  Future<List<SpaceDetailSchema>> totemCirclesApiListSpaces();
}
