// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/livekit_token_response_schema.dart';

part 'meetings_client.g.dart';

@RestApi()
abstract class MeetingsClient {
  factory MeetingsClient(Dio dio, {String? baseUrl}) = _MeetingsClient;

  /// Get Livekit Token
  @GET('/api/mobile/protected/meetings/event/{event_slug}/token')
  Future<LivekitTokenResponseSchema> totemMeetingsMobileApiGetLivekitToken({
    @Path('event_slug') required String eventSlug,
  });
}
