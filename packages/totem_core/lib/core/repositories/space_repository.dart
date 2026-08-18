import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/errors/app_exceptions.dart';
import 'package:totem_core/core/services/api_service.dart';
import 'package:totem_core/core/services/cache_service.dart';
import 'package:totem_core/core/services/repository_utils.dart';
import 'package:totem_core/shared/logger.dart';

part 'space_repository.g.dart';

Duration? _noRetry(int retryCount, Object error) => null;

bool _isRecoverableNetworkFailure(Object error) =>
    error is AppNetworkException ||
    (error is ApiError && error.statusCode >= 500);

bool _isRsvpConflict(Object error) =>
    error is ApiError<SessionDetailSchema, SessionConflictSchema> &&
    error.error != null;

@Riverpod(keepAlive: true)
Future<List<MobileSpaceDetailSchema>> listSpaces(Ref ref) async {
  final mobileApiService = ref.read(apiServiceProvider);
  final cache = ref.read(cacheServiceProvider);

  try {
    final response = await RepositoryUtils.handleApiCall(
      apiCall: () => mobileApiService.spaces.totemSpacesMobileApiListSpaces(),
      operationName: 'list spaces',
      retryOnNetworkError: true,
    );
    final spaces = response.items;

    cache.saveSpaces(spaces);

    return spaces;
  } catch (error) {
    if (!_isRecoverableNetworkFailure(error)) rethrow;
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
    retryOnNetworkError: true,
    diagnostics: {'event_slug': eventSlug},
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
    retryOnNetworkError: true,
    diagnostics: {'space_slug': spaceSlug},
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
      retryOnNetworkError: true,
    );
    cache.saveSubscribedSpaces(spaces);
    return spaces;
  } catch (error) {
    if (!_isRecoverableNetworkFailure(error)) rethrow;
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
    diagnostics: {'space_slug': spaceSlug},
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
    diagnostics: {'space_slug': spaceSlug},
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
    retryOnNetworkError: true,
    diagnostics: {'keeper_slug': keeperSlug},
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
          retryOnNetworkError: true,
        );
    cache.saveSessionsHistory(sessions);
    return sessions;
  } catch (error) {
    if (!_isRecoverableNetworkFailure(error)) rethrow;
    final cachedSessions = await cache.getSessionsHistory();
    if (cachedSessions != null) {
      return cachedSessions;
    } else {
      rethrow;
    }
  }
}

// TODO(totem): These hard coded categories should be fetched from the API.
// It is safe for now since there are only a few spaces to categorize.
enum SpaceCategories {
  allies('allies'),
  loveAndEmotions('love-emotions'),
  mothers('mothers'),
  queer('queer'),
  selfImprovement('self-improvement');

  const SpaceCategories(this.slug);

  final String slug;
}

@riverpod
Future<List<SessionDetailSchema>> getRecommendedSessions(
  Ref ref, [
  Set<SpaceCategories>? topics,
]) {
  final mobileApiService = ref.read(apiServiceProvider);
  return RepositoryUtils.handleApiCall<List<SessionDetailSchema>>(
    apiCall: () =>
        mobileApiService.spaces.totemSpacesMobileApiGetRecommendedSpaces(
          categories: topics?.map((topic) => topic.slug).toList(),
        ),
    operationName: 'get recommended sessions',
    maxRetries: 0,
    timeout: const Duration(seconds: 5),
    diagnostics: {
      if (topics != null)
        'topics': topics.map((topic) => topic.slug).toList(growable: false),
    },
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
      retryOnNetworkError: true,
    );

    cache.saveSpacesSummary(summary);

    return summary;
  } catch (error) {
    if (!_isRecoverableNetworkFailure(error)) rethrow;
    final cachedSummary = await cache.getSpacesSummary();
    if (cachedSummary != null) {
      logger.w('Using cached spaces summary due to error', error: error);
      return cachedSummary;
    } else {
      rethrow;
    }
  }
}

@Riverpod(retry: _noRetry)
Future<bool> rsvpConfirm(Ref ref, String eventSlug) async {
  final mobileApiService = ref.read(apiServiceProvider);

  try {
    final session = await RepositoryUtils.handleApiCall<SessionDetailSchema>(
      apiCall: () => mobileApiService.spaces.totemSpacesMobileApiRsvpConfirm(
        eventSlug: eventSlug,
      ),
      operationName: 'confirm RSVP for $eventSlug',
      diagnostics: {'event_slug': eventSlug},
      shouldReport: (error) => !_isRsvpConflict(error),
    );
    return session.attending;
  } on ApiError<SessionDetailSchema, SessionConflictSchema> catch (error) {
    final conflictingSession = error.error;
    if (conflictingSession != null) {
      throw RsvpConflictException(conflictingSession);
    }

    return false;
  } catch (_) {
    return false;
  }
}

/// Indicates that an RSVP could not be confirmed because the user is already
/// attending another session at the same time.
final class RsvpConflictException implements Exception {
  const RsvpConflictException(this.conflict);

  final SessionConflictSchema conflict;
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
      diagnostics: {'event_slug': eventSlug},
    );
    return session.attending;
  } catch (_) {
    return false;
  }
}

@riverpod
Future<bool> rsvpForceConfirm(
  Ref ref,
  String eventSlug,
  List<String> conflictingSessionSlugs,
) async {
  final mobileApiService = ref.read(apiServiceProvider);

  try {
    final session = await RepositoryUtils.handleApiCall<SessionDetailSchema>(
      apiCall: () =>
          mobileApiService.spaces.totemSpacesMobileApiRsvpResolveConflicts(
            eventSlug: eventSlug,
            body: ResolveConflictsSchema(
              conflictingSessionSlugs: conflictingSessionSlugs,
            ),
          ),
      operationName: 'switch RSVP to $eventSlug',
      diagnostics: {
        'event_slug': eventSlug,
        'conflicting_session_slugs': conflictingSessionSlugs,
      },
    );
    return session.attending;
  } catch (_) {
    return false;
  }
}
