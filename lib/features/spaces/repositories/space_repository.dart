import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_app/api/models/event_detail_schema.dart';
import 'package:totem_app/api/models/space_detail_schema.dart';
import 'package:totem_app/core/services/api_service.dart';

part 'space_repository.g.dart';

@riverpod
Future<List<SpaceDetailSchema>> listSpaces(Ref ref) async {
  // The API needs to be accessed somehow.
  // ignore: avoid_manual_providers_as_generated_provider_dependency
  final apiService = ref.watch(apiServiceProvider);
  // Finally, we convert the Map into an Activity instance.
  return apiService.spaces.totemCirclesApiListSpaces();
}

@riverpod
Future<EventDetailSchema> event(Ref ref, String eventId) async {
  // The API needs to be accessed somehow.
  // ignore: avoid_manual_providers_as_generated_provider_dependency
  final apiService = ref.watch(apiServiceProvider);
  // Finally, we convert the Map into an Activity instance.
  return apiService.events.totemCirclesApiEventDetail(eventSlug: eventId);
}
