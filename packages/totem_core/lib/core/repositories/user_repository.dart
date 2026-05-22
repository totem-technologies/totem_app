import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/services/api_service.dart';
import 'package:totem_core/core/services/repository_utils.dart';

part 'user_repository.g.dart';

@riverpod
Future<PublicUserSchema> userProfile(Ref ref, String slug) {
  final apiService = ref.read(apiServiceProvider);
  return RepositoryUtils.handleApiCall<PublicUserSchema>(
    apiCall: () => apiService.users.totemUsersMobileApiGetUserProfile(
      userSlug: slug,
    ),
    operationName: 'get user profile',
  );
}

@riverpod
Future<bool> submitFeedback(Ref ref, String feedback) {
  final apiService = ref.read(apiServiceProvider);
  return RepositoryUtils.handleApiCall<bool>(
    apiCall: () => apiService.users.totemUsersMobileApiSubmitFeedback(
      body: FeedbackSchema(message: feedback),
    ),
    operationName: 'submit feedback',
  );
}
