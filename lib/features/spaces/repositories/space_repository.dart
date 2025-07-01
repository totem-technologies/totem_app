import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_app/api/export.dart';
import 'package:totem_app/core/services/api_service.dart';

part 'space_repository.g.dart';

@riverpod
Future<List<SpaceDetailSchema>> listSpaces(Ref ref) async {
  final mobileApiService = ref.watch(mobileApiServiceProvider);
  return (await mobileApiService.spaces.totemCirclesMobileApiListSpaces())
      .items;
}

@riverpod
Future<EventDetailSchema> event(Ref ref, String eventSlug) async {
  final mobileApiService = ref.watch(mobileApiServiceProvider);
  return mobileApiService.spaces.totemCirclesMobileApiGetSpaceDetail(
    eventSlug: eventSlug,
  );
}
