import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_app/api/models/livekit_mute_participant_schema.dart';
import 'package:totem_app/core/errors/app_exceptions.dart';
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/core/services/api_service.dart';

part 'session_repository.g.dart';

const int _maxRetries = 2;
Duration _getRetryDelay(int attempt) {
  return Duration(milliseconds: 500 * (1 << attempt)); // 500ms, 1s, 2s
}

Future<T> _handleApiCall<T>({
  required Future<T> Function() apiCall,
  required String operationName,
  bool retryOnNetworkError = false,
  int maxRetries = _maxRetries,
}) async {
  int attempt = 0;
  while (true) {
    try {
      return await apiCall();
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Error in $operationName',
      );

      // Don't retry on auth errors or client errors (4xx)
      if (error is AppAuthException) {
        rethrow;
      }

      if (error is DioException) {
        final statusCode = error.response?.statusCode;
        // Don't retry on client errors (4xx)
        if (statusCode != null && statusCode >= 400 && statusCode < 500) {
          rethrow;
        }
      }

      // Retry logic for network errors
      if (retryOnNetworkError &&
          attempt < maxRetries &&
          (error is AppNetworkException ||
              error is DioException ||
              error is TimeoutException)) {
        attempt++;
        debugPrint(
          'Retrying $operationName (attempt $attempt/$maxRetries)...',
        );
        await Future<void>.delayed(_getRetryDelay(attempt - 1));
        continue;
      }

      rethrow;
    }
  }
}

@riverpod
Future<String> sessionToken(Ref ref, String eventSlug) async {
  final apiService = ref.read(mobileApiServiceProvider);
  return _handleApiCall<String>(
    apiCall: () async {
      final response = await apiService.meetings
          .totemMeetingsMobileApiGetLivekitToken(eventSlug: eventSlug);
      return response.token;
    },
    operationName: 'get session token',
    retryOnNetworkError: true,
  );
}

@riverpod
Future<void> removeParticipant(
  Ref ref,
  String eventSlug,
  String participantIdentity,
) async {
  final apiService = ref.read(mobileApiServiceProvider);
  await _handleApiCall<void>(
    apiCall: () =>
        apiService.meetings.totemMeetingsMobileApiRemoveParticipantEndpoint(
          eventSlug: eventSlug,
          participantIdentity: participantIdentity,
        ),
    operationName: 'remove participant',
    retryOnNetworkError: true,
  );
}

/// Mutes a participant.
///
/// An error can be thrown if the participant is already muted.
@riverpod
Future<void> muteParticipant(
  Ref ref,
  String eventSlug,
  String participantIdentity,
) async {
  final apiService = ref.read(mobileApiServiceProvider);
  await _handleApiCall<void>(
    apiCall: () =>
        apiService.meetings.totemMeetingsMobileApiMuteParticipantEndpoint(
          eventSlug: eventSlug,
          participantIdentity: participantIdentity,
        ),
    operationName: 'mute participant',
    retryOnNetworkError: true,
  );
}

@riverpod
Future<void> muteEveryone(
  Ref ref,
  String eventSlug,
  List<String> participantIdentities,
) async {
  for (final participantIdentity in participantIdentities) {
    await ref.read(
      muteParticipantProvider(eventSlug, participantIdentity).future,
    );
  }
}

@riverpod
Future<void> passTotem(Ref ref, String eventSlug) async {
  final apiService = ref.read(mobileApiServiceProvider);
  await _handleApiCall<void>(
    apiCall: () => apiService.meetings.totemMeetingsMobileApiPassTotemEndpoint(
      eventSlug: eventSlug,
    ),
    operationName: 'pass totem',
    retryOnNetworkError: true,
  );
}

@riverpod
Future<void> reorderParticipants(
  Ref ref,
  String eventSlug,
  List<String> order,
) async {
  final apiService = ref.read(mobileApiServiceProvider);
  await _handleApiCall<void>(
    apiCall: () =>
        apiService.meetings.totemMeetingsMobileApiReorderParticipantsEndpoint(
          eventSlug: eventSlug,
          body: LivekitMuteParticipantSchema(order: order),
        ),
    operationName: 'reorder participants',
    retryOnNetworkError: true,
  );
}

@riverpod
Future<void> startSession(Ref ref, String eventSlug) async {
  final apiService = ref.read(mobileApiServiceProvider);
  await _handleApiCall<void>(
    apiCall: () => apiService.meetings.totemMeetingsMobileApiStartRoomEndpoint(
      eventSlug: eventSlug,
    ),
    operationName: 'start session',
    retryOnNetworkError: true,
  );
}

@riverpod
Future<void> endSession(Ref ref, String eventSlug) async {
  final apiService = ref.read(mobileApiServiceProvider);
  await _handleApiCall<void>(
    apiCall: () => apiService.meetings.totemMeetingsMobileApiEndRoomEndpoint(
      eventSlug: eventSlug,
    ),
    operationName: 'end session',
    retryOnNetworkError: true,
  );
}
