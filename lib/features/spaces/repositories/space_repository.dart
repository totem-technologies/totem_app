import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_app/api/export.dart';
import 'package:totem_app/core/services/api_service.dart';

part 'space_repository.g.dart';

@riverpod
Future<List<SpaceDetailSchema>> listSpaces(Ref ref) async {
  final apiService = ref.watch(apiServiceProvider);
  // Finally, we convert the Map into an Activity instance.
  return await apiService.spaces.totemCirclesApiListSpaces();
}

@riverpod
Future<EventDetailSchema> event(Ref ref, String eventId) async {
  final apiService = ref.watch(apiServiceProvider);
  // Finally, we convert the Map into an Activity instance.
  return await apiService.events.totemCirclesApiEventDetail(eventSlug: eventId);
}
