import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_app/api/models/feedback_schema.dart';
import 'package:totem_app/api/models/public_user_schema.dart';
import 'package:totem_app/core/services/api_service.dart';

part 'user_repository.g.dart';

@riverpod
Future<PublicUserSchema> userProfile(Ref ref, String slug) {
  final apiService = ref.watch(mobileApiServiceProvider);
  return apiService.users.totemUsersMobileApiGetUserProfile(userSlug: slug);
}

@riverpod
Future<bool> submitFeedback(Ref ref, String feedback) {
  final apiService = ref.watch(mobileApiServiceProvider);
  return apiService.users.totemUsersMobileApiSubmitFeedback(
    body: FeedbackSchema(message: feedback),
  );
}
