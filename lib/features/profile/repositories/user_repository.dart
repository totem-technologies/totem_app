import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_app/api/models/public_user_schema.dart';
import 'package:totem_app/core/services/api_service.dart';

part 'user_repository.g.dart';

@riverpod
Future<PublicUserSchema> userProfile(Ref ref, String slug) {
  final apiService = ref.watch(mobileApiServiceProvider);
  return apiService.users.totemUsersMobileApiGetUserProfile(userSlug: slug);
}
