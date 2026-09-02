import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/services/api_service.dart';
import 'package:totem_core/core/services/repository_utils.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  final apiService = ref.read(apiServiceProvider);
  return UserRepository(apiService: apiService);
}, name: 'User Repository Provider');

class UserRepository {
  const UserRepository({required this.apiService});

  final ClientApi apiService;

  Future<UserSchema> get currentUser async {
    return RepositoryUtils.handleApiCall<UserSchema>(
      apiCall: () => apiService.users.totemUsersMobileApiGetCurrentUser(),
      operationName: 'fetch current user',
    );
  }

  Future<bool> updateCurrentUserProfilePicture(File file) async {
    final bytes = await file.readAsBytes();
    return RepositoryUtils.handleApiCall<bool>(
      apiCall: () => apiService.users.totemUsersMobileApiUpdateCurrentUserImage(
        body: UpdateCurrentUserImageRequest(profileImage: bytes),
      ),
      operationName: 'update current user profile picture',
    );
  }

  Future<UserSchema> updateCurrentUserProfile({
    String? name,
    String? email,
    String? timezone,
    bool? newsletterConsent,
    ProfileAvatarTypeEnum? profileAvatarType,
    String? avatarSeed,
  }) async {
    return RepositoryUtils.handleApiCall<UserSchema>(
      apiCall: () => apiService.users.totemUsersMobileApiUpdateCurrentUser(
        body: UserUpdateSchema(
          name: name,
          email: email,
          timezone: timezone,
          newsletterConsent: newsletterConsent,
          profileAvatarType: profileAvatarType,
          profileAvatarSeed: avatarSeed,
        ),
      ),
      operationName: 'update current user profile',
    );
  }

  Future<OnboardSchema> get onboardStatus async {
    return RepositoryUtils.handleApiCall<OnboardSchema>(
      apiCall: () => apiService.$default.totemOnboardMobileApiOnboardGet(),
      operationName: 'fetch onboard status',
    );
  }

  Future<OnboardSchema> completeOnboarding({
    required ReferralChoices? referralSource,
    required Set<String> interestTopics,
    int? yearBorn,
    String? referralOther,
  }) async {
    return RepositoryUtils.handleApiCall<OnboardSchema>(
      apiCall: () => apiService.$default.totemOnboardMobileApiOnboardPost(
        body: OnboardSchema(
          referralSource: referralSource ?? ReferralChoices.$default,
          referralOther: referralOther ?? '',
          hopes: interestTopics.join(', '),
          yearBorn: yearBorn,
        ),
      ),
      operationName: 'complete onboarding',
    );
  }

  Future<void> deleteAccount() async {
    return RepositoryUtils.handleApiCall<void>(
      apiCall: () => apiService.users.totemUsersMobileApiDeleteCurrentUser(),
      operationName: 'delete account',
    );
  }
}
