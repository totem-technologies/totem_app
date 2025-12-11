import 'dart:async';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_app/api/export.dart';
import 'package:totem_app/core/services/api_service.dart';
import 'package:totem_app/core/services/cache_service.dart';
import 'package:totem_app/core/services/repository_utils.dart';

part 'space_repository.g.dart';

@Riverpod(keepAlive: true)
Future<List<MobileSpaceDetailSchema>> listSpaces(Ref ref) async {
  final mobileApiService = ref.watch(mobileApiServiceProvider);
  final cache = ref.watch(cacheServiceProvider);

  try {
    final response = await RepositoryUtils.handleApiCall(
      apiCall: () =>
          mobileApiService.spaces.totemCirclesMobileApiMobileApiListSpaces(),
      operationName: 'list spaces',
    );
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
  return RepositoryUtils.handleApiCall<EventDetailSchema>(
    apiCall: () =>
        mobileApiService.spaces.totemCirclesMobileApiMobileApiGetEventDetail(
          eventSlug: eventSlug,
        ),
    operationName: 'get event detail',
  );
}

@riverpod
Future<MobileSpaceDetailSchema> space(Ref ref, String spaceSlug) async {
  final mobileApiService = ref.watch(mobileApiServiceProvider);
  return RepositoryUtils.handleApiCall<MobileSpaceDetailSchema>(
    apiCall: () =>
        mobileApiService.spaces.totemCirclesMobileApiMobileApiGetSpaceDetail(
          spaceSlug: spaceSlug,
        ),
    operationName: 'get space detail',
  );
}

@riverpod
Future<List<SpaceSchema>> listSubscribedSpaces(Ref ref) async {
  final mobileApiService = ref.watch(mobileApiServiceProvider);
  final cache = ref.watch(cacheServiceProvider);
  try {
    final spaces = await RepositoryUtils.handleApiCall<List<SpaceSchema>>(
      apiCall: () => mobileApiService.spaces
          .totemCirclesMobileApiMobileApiListSubscriptions(),
      operationName: 'list subscribed spaces',
    );
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
  return RepositoryUtils.handleApiCall<bool>(
    apiCall: () =>
        mobileApiService.spaces.totemCirclesMobileApiMobileApiSubscribeToSpace(
          spaceSlug: spaceSlug,
        ),
    operationName: 'subscribe to space',
  );
}

@riverpod
Future<bool> unsubscribeFromSpace(
  Ref ref,
  String spaceSlug,
) async {
  final mobileApiService = ref.watch(mobileApiServiceProvider);
  final success = await RepositoryUtils.handleApiCall<bool>(
    apiCall: () => mobileApiService.spaces
        .totemCirclesMobileApiMobileApiUnsubscribeToSpace(
          spaceSlug: spaceSlug,
        ),
    operationName: 'unsubscribe from space',
  );

  final refreshable = ref.refresh(listSubscribedSpacesProvider.future);
  await refreshable;

  return success;
}

@riverpod
Future<List<MobileSpaceDetailSchema>> listSpacesByKeeper(
  Ref ref,
  String keeperSlug,
) async {
  final mobileApiService = ref.watch(mobileApiServiceProvider);
  return RepositoryUtils.handleApiCall<List<MobileSpaceDetailSchema>>(
    apiCall: () =>
        mobileApiService.spaces.totemCirclesMobileApiMobileApiGetKeeperSpaces(
          slug: keeperSlug,
        ),
    operationName: 'list spaces by keeper',
  );
}

@riverpod
Future<List<EventDetailSchema>> listSessionsHistory(Ref ref) async {
  final mobileApiService = ref.watch(mobileApiServiceProvider);
  final cache = ref.watch(cacheServiceProvider);

  try {
    final sessions =
        await RepositoryUtils.handleApiCall<List<EventDetailSchema>>(
          apiCall: () => mobileApiService.spaces
              .totemCirclesMobileApiMobileApiGetSessionsHistory(),
          operationName: 'list sessions history',
        );
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

@riverpod
Future<List<EventDetailSchema>> getRecommendedSessions(
  Ref ref, [
  String? topicsKey,
]) {
  final mobileApiService = ref.watch(mobileApiServiceProvider);
  final List<String>? body = topicsKey == null || topicsKey.isEmpty
      ? null
      : topicsKey.split('|').toList();
  return RepositoryUtils.handleApiCall<List<EventDetailSchema>>(
    apiCall: () => mobileApiService.spaces
        .totemCirclesMobileApiMobileApiGetRecommendedSpaces(
          body: body,
        ),
    operationName: 'get recommended sessions',
  );
}
