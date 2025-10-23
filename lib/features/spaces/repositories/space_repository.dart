import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_app/api/export.dart';
import 'package:totem_app/core/services/api_service.dart';
import 'package:totem_app/core/services/cache_service.dart';

part 'space_repository.g.dart';

@Riverpod(keepAlive: true)
Future<List<SpaceDetailSchema>> listSpaces(Ref ref) async {
  final mobileApiService = ref.watch(mobileApiServiceProvider);
  final cache = ref.watch(cacheServiceProvider);

  try {
    final response = await mobileApiService.spaces
        .totemCirclesMobileApiListSpaces();
    final spaces = response.items;

    unawaited(cache.saveSpaces(spaces));

    return spaces;
  } on DioException catch (_) {
    final cachedSpaces = await cache.getSpaces();
    if (cachedSpaces != null) {
      return cachedSpaces;
    } else {
      rethrow;
    }
  }
}

@riverpod
Future<EventDetailSchema> event(Ref ref, String eventSlug) async {
  final mobileApiService = ref.watch(mobileApiServiceProvider);
  return mobileApiService.spaces.totemCirclesMobileApiGetEventDetail(
    eventSlug: eventSlug,
  );
}

@riverpod
Future<SpaceDetailSchema> space(Ref ref, String spaceSlug) async {
  final mobileApiService = ref.watch(mobileApiServiceProvider);
  return mobileApiService.spaces.totemCirclesMobileApiGetSpaceDetail(
    spaceSlug: spaceSlug,
  );
}

@riverpod
Future<List<SpaceSchema>> listSubscribedSpaces(Ref ref) async {
  final mobileApiService = ref.watch(mobileApiServiceProvider);
  final cache = ref.watch(cacheServiceProvider);
  try {
    final spaces = await mobileApiService.spaces
        .totemCirclesMobileApiListSubscriptions();
    unawaited(cache.saveSubscribedSpaces(spaces));
    return spaces;
  } on DioException catch (_) {
    // final cachedSpaces = await cache.getSubscribedSpaces();
    // if (cachedSpaces != null) {
    //   return cachedSpaces;
    // } else {
    //   rethrow;
    // }
    rethrow;
  }
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

@riverpod
Future<List<EventDetailSchema>> listSessionsHistory(Ref ref) async {
  final mobileApiService = ref.watch(mobileApiServiceProvider);
  final cache = ref.watch(cacheServiceProvider);

  try {
    final sessions = await mobileApiService.spaces
        .totemCirclesMobileApiGetSessionsHistory();
    unawaited(cache.saveSessionsHistory(sessions));
    return sessions;
  } on DioException catch (_) {
    final cachedSessions = await cache.getSessionsHistory();
    if (cachedSessions != null) {
      return cachedSessions;
    } else {
      rethrow;
    }
  }
}

/// Recommended spaces based on a list of suggestion names (topics/categories).
/// Uses the existing mobile API client method which calls
/// `/api/mobile/protected/spaces/recommended` with a request body of
/// `List<String>` and an optional `limit` query param.
final recommendedEventsByTopicsKeyProvider =
    FutureProviderFamily<List<EventDetailSchema>, String>((
      ref,
      topicsKey,
    ) async {
      final mobileApiService = ref.watch(mobileApiServiceProvider);
      final List<String>? body = topicsKey.isEmpty
          ? null
          : topicsKey.split('|');
      final events = await mobileApiService.spaces
          .totemCirclesMobileApiGetRecommendedSpaces(body: body);
      return events;
    });
