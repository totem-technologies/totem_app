import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_app/api/models/summary_spaces_schema.dart';
import 'package:totem_app/core/services/api_service.dart';
import 'package:totem_app/core/services/cache_service.dart';

part 'home_screen_repository.g.dart';

@Riverpod(keepAlive: true)
Future<SummarySpacesSchema> spacesSummary(Ref ref) async {
  final mobileApiService = ref.watch(mobileApiServiceProvider);
  final cache = ref.watch(cacheServiceProvider);

  try {
    final summary = await mobileApiService.spaces
        .totemCirclesMobileApiGetSpacesSummary();

    unawaited(cache.saveSpacesSummary(summary));

    return summary;
  } on DioException catch (e) {
    final cachedSummary = await cache.getSpacesSummary();
    if (cachedSummary != null) {
      debugPrint('Using cached spaces summary due to error: $e');
      return cachedSummary;
    } else {
      rethrow;
    }
  }
}
