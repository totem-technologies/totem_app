import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_app/api/mobile_totem_api.dart';
import 'package:totem_app/api/models/feedback_schema.dart';
import 'package:totem_app/api/models/public_user_schema.dart';
import 'package:totem_app/core/services/api_service.dart';
import 'package:totem_app/core/services/repository_utils.dart';

part 'user_repository.g.dart';

const userProfileCacheTtl = Duration(minutes: 10);

final publicUserProfileCacheProvider = Provider<PublicUserProfileCache>((ref) {
  return PublicUserProfileCache();
});

class PublicUserProfileCache {
  PublicUserProfileCache({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final _cache = <String, _CachedPublicUserProfile>{};
  final _inFlightRequests = <String, Future<PublicUserSchema>>{};

  Future<PublicUserSchema> getProfile(
    MobileTotemApi apiService,
    String slug, {
    Duration maxAge = userProfileCacheTtl,
    bool forceRefresh = false,
  }) {
    final inFlightRequest = _inFlightRequests[slug];
    if (inFlightRequest != null) return inFlightRequest;

    if (!forceRefresh) {
      final cachedProfile = _cache[slug];
      if (cachedProfile != null && !cachedProfile.isExpired(_now(), maxAge)) {
        return Future.value(cachedProfile.user);
      }
    }

    final request =
        RepositoryUtils.handleApiCall<PublicUserSchema>(
              apiCall: () => apiService.users.totemUsersMobileApiGetUserProfile(
                userSlug: slug,
              ),
              operationName: 'get user profile',
            )
            .then((user) {
              _cache[slug] = _CachedPublicUserProfile(
                user: user,
                fetchedAt: _now(),
              );
              _inFlightRequests.remove(slug);
              return user;
            })
            .catchError((Object error, StackTrace stackTrace) {
              _inFlightRequests.remove(slug);
              Error.throwWithStackTrace(error, stackTrace);
            });

    _inFlightRequests[slug] = request;
    return request;
  }

  Duration? remainingFreshness(
    String slug, {
    Duration maxAge = userProfileCacheTtl,
  }) {
    final cachedProfile = _cache[slug];
    if (cachedProfile == null) return null;

    final age = _now().difference(cachedProfile.fetchedAt);
    if (age >= maxAge) return Duration.zero;
    return maxAge - age;
  }

  void invalidate(String slug) {
    _cache.remove(slug);
  }

  void clear() {
    _cache.clear();
  }
}

class _CachedPublicUserProfile {
  const _CachedPublicUserProfile({required this.user, required this.fetchedAt});

  final PublicUserSchema user;
  final DateTime fetchedAt;

  bool isExpired(DateTime now, Duration maxAge) =>
      now.difference(fetchedAt) >= maxAge;
}

@riverpod
Future<PublicUserSchema> userProfile(Ref ref, String slug) async {
  final apiService = ref.read(mobileApiServiceProvider);
  final cache = ref.read(publicUserProfileCacheProvider);

  Timer? refreshTimer;
  ref.onDispose(() => refreshTimer?.cancel());

  final profile = await cache.getProfile(apiService, slug);
  final refreshIn = cache.remainingFreshness(slug) ?? userProfileCacheTtl;
  refreshTimer = Timer(refreshIn, ref.invalidateSelf);
  return profile;
}

@riverpod
Future<bool> submitFeedback(Ref ref, String feedback) {
  final apiService = ref.read(mobileApiServiceProvider);
  return RepositoryUtils.handleApiCall<bool>(
    apiCall: () => apiService.users.totemUsersMobileApiSubmitFeedback(
      body: FeedbackSchema(message: feedback),
    ),
    operationName: 'submit feedback',
  );
}
