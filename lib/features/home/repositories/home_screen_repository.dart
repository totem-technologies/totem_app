import 'dart:async';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_app/core/api/lib/totem_mobile_api.dart';
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/core/services/api_service.dart';
import 'package:totem_app/core/services/cache_service.dart';
import 'package:totem_app/core/services/repository_utils.dart';
import 'package:totem_app/shared/logger.dart';

part 'home_screen_repository.g.dart';

@Riverpod(keepAlive: true)
Future<SummarySpacesSchema> spacesSummary(Ref ref) async {
  final mobileApiService = ref.read(mobileApiServiceProvider);
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
  final mobileApiService = ref.read(mobileApiServiceProvider);

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
  final mobileApiService = ref.read(mobileApiServiceProvider);

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
