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

  Future<UserSchema> get currentUser {
    return RepositoryUtils.handleApiCall<UserSchema>(
      apiCall: () => apiService.users.totemUsersMobileApiGetCurrentUser(),
      operationName: 'fetch current user',
    );
  }

  Future<bool> updateCurrentUserProfilePicture(File file) async {
    final bytes = await file.readAsBytes();
    return await RepositoryUtils.handleApiCall<bool>(
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
  }) {
    return RepositoryUtils.handleApiCall<UserSchema>(
      apiCall: () => apiService.users.totemUsersMobileApiUpdateCurrentUser(
        body: UserUpdateSchema(
          name: name == null ? const Omittable.absent() : Omittable(name),
          email: email == null ? const Omittable.absent() : Omittable(email),
          timezone: timezone == null
              ? const Omittable.absent()
              : Omittable(timezone),
          newsletterConsent: newsletterConsent == null
              ? const Omittable.absent()
              : Omittable(newsletterConsent),
          profileAvatarType: profileAvatarType == null
              ? const Omittable.absent()
              : Omittable(profileAvatarType),
          profileAvatarSeed: avatarSeed == null
              ? const Omittable.absent()
              : Omittable(avatarSeed),
        ),
      ),
      operationName: 'update current user profile',
    );
  }

  Future<OnboardSchema> get onboardStatus {
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
  }) {
    return RepositoryUtils.handleApiCall<OnboardSchema>(
      apiCall: () => apiService.$default.totemOnboardMobileApiOnboardPost(
        body: OnboardSchema(
          referralSource: referralSource ?? ReferralChoices.$default,
          referralOther: Omittable(referralOther ?? ''),
          hopes: Omittable(interestTopics.join(', ')),
          yearBorn: yearBorn == null
              ? const Omittable.absent()
              : Omittable(yearBorn),
        ),
      ),
      operationName: 'complete onboarding',
    );
  }

  Future<void> deleteAccount() {
    return RepositoryUtils.handleApiCall<void>(
      apiCall: () => apiService.users.totemUsersMobileApiDeleteCurrentUser(),
      operationName: 'delete account',
    );
  }
}
