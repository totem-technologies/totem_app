import 'dart:async';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/core/services/api_service.dart';
import 'package:totem_core/core/services/cache_service.dart';
import 'package:totem_core/core/services/repository_utils.dart';
import 'package:totem_core/shared/logger.dart';

part 'space_repository.g.dart';

@Riverpod(keepAlive: true)
Future<List<MobileSpaceDetailSchema>> listSpaces(Ref ref) async {
  final mobileApiService = ref.read(apiServiceProvider);
  final cache = ref.read(cacheServiceProvider);

  try {
    final response = await RepositoryUtils.handleApiCall(
      apiCall: () => mobileApiService.spaces.totemSpacesMobileApiListSpaces(),
      operationName: 'list spaces',
    );
    final spaces = response.items;

    cache.saveSpaces(spaces);

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
Future<SessionDetailSchema> event(Ref ref, String eventSlug) async {
  final mobileApiService = ref.read(apiServiceProvider);
  return RepositoryUtils.handleApiCall<SessionDetailSchema>(
    apiCall: () => mobileApiService.spaces.totemSpacesMobileApiGetSessionDetail(
      eventSlug: eventSlug,
    ),
    operationName: 'get event detail',
  );
}

@riverpod
Future<MobileSpaceDetailSchema> space(Ref ref, String spaceSlug) async {
  final mobileApiService = ref.read(apiServiceProvider);
  return RepositoryUtils.handleApiCall<MobileSpaceDetailSchema>(
    apiCall: () => mobileApiService.spaces.totemSpacesMobileApiGetSpaceDetail(
      spaceSlug: spaceSlug,
    ),
    operationName: 'get space detail',
  );
}

@riverpod
Future<List<SpaceSchema>> listSubscribedSpaces(Ref ref) async {
  final mobileApiService = ref.read(apiServiceProvider);
  final cache = ref.read(cacheServiceProvider);
  try {
    final spaces = await RepositoryUtils.handleApiCall<List<SpaceSchema>>(
      apiCall: () =>
          mobileApiService.spaces.totemSpacesMobileApiListSubscriptions(),
      operationName: 'list subscribed spaces',
    );
    cache.saveSubscribedSpaces(spaces);
    return spaces;
  } on DioException catch (_) {
    final cachedSpaces = await cache.getSubscribedSpaces();
    if (cachedSpaces != null) {
      return cachedSpaces;
    } else {
      rethrow;
    }
  }
}

@riverpod
Future<bool> subscribeToSpace(Ref ref, String spaceSlug) async {
  final mobileApiService = ref.read(apiServiceProvider);
  return RepositoryUtils.handleApiCall<bool>(
    apiCall: () => mobileApiService.spaces.totemSpacesMobileApiSubscribeToSpace(
      spaceSlug: spaceSlug,
    ),
    operationName: 'subscribe to space',
  );
}

@riverpod
Future<bool> unsubscribeFromSpace(Ref ref, String spaceSlug) async {
  final mobileApiService = ref.read(apiServiceProvider);
  final success = await RepositoryUtils.handleApiCall<bool>(
    apiCall: () =>
        mobileApiService.spaces.totemSpacesMobileApiUnsubscribeToSpace(
          spaceSlug: spaceSlug,
        ),
    operationName: 'unsubscribe from space',
  );

  if (ref.mounted) {
    final refreshable = ref.refresh(listSubscribedSpacesProvider.future);
    await refreshable;
  }

  return success;
}

@riverpod
Future<List<MobileSpaceDetailSchema>> listSpacesByKeeper(
  Ref ref,
  String keeperSlug,
) async {
  final mobileApiService = ref.read(apiServiceProvider);
  return RepositoryUtils.handleApiCall<List<MobileSpaceDetailSchema>>(
    apiCall: () => mobileApiService.spaces.totemSpacesMobileApiGetKeeperSpaces(
      slug: keeperSlug,
    ),
    operationName: 'list spaces by keeper',
  );
}

@riverpod
Future<List<SessionDetailSchema>> listSessionsHistory(Ref ref) async {
  final mobileApiService = ref.read(apiServiceProvider);
  final cache = ref.read(cacheServiceProvider);

  try {
    final sessions =
        await RepositoryUtils.handleApiCall<List<SessionDetailSchema>>(
          apiCall: () =>
              mobileApiService.spaces.totemSpacesMobileApiGetSessionsHistory(),
          operationName: 'list sessions history',
        );
    cache.saveSessionsHistory(sessions);
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
Future<List<SessionDetailSchema>> getRecommendedSessions(
  Ref ref, [
  String? topicsKey,
]) {
  final mobileApiService = ref.read(apiServiceProvider);
  final List<String>? body = topicsKey == null || topicsKey.isEmpty
      ? null
      : topicsKey.split('|').toList();
  return RepositoryUtils.handleApiCall<List<SessionDetailSchema>>(
    apiCall: () => mobileApiService.spaces
        .totemSpacesMobileApiGetRecommendedSpaces(body: body),
    operationName: 'get recommended sessions',
    maxRetries: 0,
    timeout: const Duration(seconds: 5),
  );
}

@Riverpod(keepAlive: true)
Future<SummarySpacesSchema> spacesSummary(Ref ref) async {
  final mobileApiService = ref.read(apiServiceProvider);
  final cache = ref.read(cacheServiceProvider);

  try {
    final summary = await RepositoryUtils.handleApiCall<SummarySpacesSchema>(
      apiCall: () =>
          mobileApiService.spaces.totemSpacesMobileApiGetSpacesSummary(),
      operationName: 'get spaces summary',
    );

    cache.saveSpacesSummary(summary);

    return summary;
  } on DioException catch (e, stackTrace) {
    final cachedSummary = await cache.getSpacesSummary();
    if (cachedSummary != null) {
      logger.w('Using cached spaces summary due to error', error: e);
      ErrorHandler.logError(
        e,
        stackTrace: stackTrace,
        message: 'Failed to fetch spaces summary, using cache',
      );
      return cachedSummary;
    } else {
      rethrow;
    }
  }
}

@riverpod
Future<bool> rsvpConfirm(Ref ref, String eventSlug) async {
  final mobileApiService = ref.read(apiServiceProvider);

  try {
    final session = await RepositoryUtils.handleApiCall<SessionDetailSchema>(
      apiCall: () => mobileApiService.spaces.totemSpacesMobileApiRsvpConfirm(
        eventSlug: eventSlug,
      ),
      operationName: 'confirm RSVP for $eventSlug',
    );
    return session.attending;
  } catch (e, stackTrace) {
    ErrorHandler.logError(
      e,
      stackTrace: stackTrace,
      message: 'Failed to confirm RSVP for $eventSlug',
    );
    return false;
  }
}

@riverpod
Future<bool> rsvpCancel(Ref ref, String eventSlug) async {
  final mobileApiService = ref.read(apiServiceProvider);

  try {
    final session = await RepositoryUtils.handleApiCall<SessionDetailSchema>(
      apiCall: () => mobileApiService.spaces.totemSpacesMobileApiRsvpCancel(
        eventSlug: eventSlug,
      ),
      operationName: 'cancel RSVP for $eventSlug',
    );
    return session.attending;
  } catch (e, stackTrace) {
    ErrorHandler.logError(
      e,
      stackTrace: stackTrace,
      message: 'Failed to cancel RSVP for $eventSlug',
    );
    return false;
  }
}
