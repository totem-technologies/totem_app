import 'dart:async';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_app/api/models/summary_spaces_schema.dart';
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/core/services/api_service.dart';
import 'package:totem_app/core/services/cache_service.dart';
import 'package:totem_app/core/services/repository_utils.dart';
import 'package:totem_app/shared/logger.dart';

part 'home_screen_repository.g.dart';

@Riverpod(keepAlive: true)
Future<SummarySpacesSchema> spacesSummary(Ref ref) async {
  final mobileApiService = ref.watch(mobileApiServiceProvider);
  final cache = ref.watch(cacheServiceProvider);

  try {
    final summary = await RepositoryUtils.handleApiCall<SummarySpacesSchema>(
      apiCall: () => mobileApiService.spaces
          .totemCirclesMobileApiMobileApiGetSpacesSummary(),
      operationName: 'get spaces summary',
    );

    unawaited(cache.saveSpacesSummary(summary));

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
