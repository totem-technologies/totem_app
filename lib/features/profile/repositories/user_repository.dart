import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_app/api/models/feedback_schema.dart';
import 'package:totem_app/api/models/public_user_schema.dart';
import 'package:totem_app/core/services/api_service.dart';
import 'package:totem_app/core/services/repository_utils.dart';

part 'user_repository.g.dart';

@riverpod
Future<PublicUserSchema> userProfile(Ref ref, String slug) {
  final apiService = ref.watch(mobileApiServiceProvider);
  return RepositoryUtils.handleApiCall<PublicUserSchema>(
    apiCall: () => apiService.users.totemUsersMobileApiGetUserProfile(
      userSlug: slug,
    ),
    operationName: 'get user profile',
  );
}

@riverpod
Future<bool> submitFeedback(Ref ref, String feedback) {
  final apiService = ref.watch(mobileApiServiceProvider);
  return RepositoryUtils.handleApiCall<bool>(
    apiCall: () => apiService.users.totemUsersMobileApiSubmitFeedback(
      body: FeedbackSchema(message: feedback),
    ),
    operationName: 'submit feedback',
  );
}
