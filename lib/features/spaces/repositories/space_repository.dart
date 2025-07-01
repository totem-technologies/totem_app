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

@riverpod
Future<List<SpaceSchema>> listSubscribedSpaces(Ref ref) async {
  final mobileApiService = ref.watch(mobileApiServiceProvider);
  return mobileApiService.spaces.totemCirclesMobileApiListSubscriptions();
}

@riverpod
Future<bool> subscribeToSpace(
  Ref ref,
  String spaceSlug,
) async {
  final mobileApiService = ref.watch(mobileApiServiceProvider);
  return mobileApiService.spaces.totemCirclesMobileApiSubscribeToSpace(
    spaceSlug: spaceSlug,
  );
}

@riverpod
Future<bool> unsubscribeFromSpace(
  Ref ref,
  String spaceSlug,
) async {
  final mobileApiService = ref.watch(mobileApiServiceProvider);
  final success = await mobileApiService.spaces
      .totemCirclesMobileApiUnsubscribeToSpace(
        spaceSlug: spaceSlug,
      );

  final refreshable = ref.refresh(listSubscribedSpacesProvider.future);
  await refreshable;

  return success;
}

@riverpod
Future<List<SpaceDetailSchema>> listSpacesByKeeper(
  Ref ref,
  String keeperSlug,
) async {
  final mobileApiService = ref.watch(mobileApiServiceProvider);
  return mobileApiService.spaces.totemCirclesMobileApiGetKeeperSpaces(
    slug: keeperSlug,
  );
}
