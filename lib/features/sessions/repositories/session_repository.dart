import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_app/core/services/api_service.dart';

part 'session_repository.g.dart';

@riverpod
Future<String> sessionToken(Ref ref, String eventSlug) async {
  final apiService = ref.read(mobileApiServiceProvider);
  final response = await apiService.meetings
      .totemMeetingsMobileApiGetLivekitToken(eventSlug: eventSlug);
  return response.token;
}
