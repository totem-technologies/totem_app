import 'dart:async';
import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_app/features/auth/controllers/auth_controller.dart';
import 'package:totem_app/features/auth/repositories/user_profile_repository.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/core/services/analytics_service.dart';
import 'package:totem_core/core/services/local_storage_service.dart';
import 'package:totem_core/shared/logger.dart';

part 'user_profile_controller.g.dart';

@riverpod
class UserProfileController extends _$UserProfileController {
  @override
  FutureOr<void> build() {
    // Initial state is void, we just use this controller for mutations
  }

  UserRepository get _userRepository => ref.read(userRepositoryProvider);
  AnalyticsService get _analyticsService => ref.read(analyticsProvider);
  MobileAuthController get _authController =>
      ref.read(mobileAuthControllerProvider);

  /// Check if the user has seen the welcome onboarding screens before
  Future<bool> get hasSeenWelcomeOnboarding async {
    return ref.read(localStorageServiceProvider).hasSeenWelcomeOnboarding();
  }

  /// Mark that the user has completed the welcome onboarding screens
  Future<void> markWelcomeOnboardingCompleted() async {
    await ref
        .read(localStorageServiceProvider)
        .markWelcomeOnboardingCompleted();
    _analyticsService.logEvent('welcome_onboarding_completed');
  }

  Future<void> completeOnboarding({
    required String firstName,
    required int? age,
    required ReferralChoices? referralSource,
    required Set<String> interestTopics,
    required bool newsletterConsent,
    String? referralOther,
  }) async {
    if (!_authController.isAuthenticated || _authController.user == null) {
      throw Exception('User not authenticated for onboarding.');
    }

    state = const AsyncLoading();

    try {
      final updatedUser = await _userRepository.updateCurrentUserProfile(
        name: firstName,
        newsletterConsent: newsletterConsent,
      );

      await _userRepository.completeOnboarding(
        interestTopics: interestTopics,
        referralSource: referralSource,
        referralOther: referralOther,
        yearBorn: age == null ? null : (DateTime.now().year - age),
      );

      logger.i('🔑 Onboard completed!');

      // Sync the newly updated user back to the AuthController's state
      _authController.syncUser(updatedUser);

      if (referralSource != null) {
        _analyticsService.logEvent(
          'referral_source',
          parameters: {
            'source': referralSource,
            'user_type': 'new_user',
            'signup_flow_step': 3,
          },
        );
      }

      _analyticsService.logEvent('onboarding_completed');
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: '🔑 Failed to complete onboarding',
      );
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<bool> updateUserProfile({
    String? name,
    String? email,
    File? profileImage,
    ProfileAvatarTypeEnum? profileAvatarType,
    String? avatarSeed,
  }) async {
    assert(
      _authController.isAuthenticated,
      'Cannot update profile when user is not authenticated.',
    );

    assert(
      profileImage != null ||
          avatarSeed != null ||
          profileAvatarType != null ||
          name != null ||
          email != null,
      'At least one profile field must be provided for update.',
    );

    var overallSuccess = true;
    var finalUpdatedUser = _authController.user;

    if (profileImage != null) {
      try {
        final bool imageUpdateSuccess = await _userRepository
            .updateCurrentUserProfilePicture(profileImage);
        if (!imageUpdateSuccess) {
          overallSuccess = false;
        }
      } catch (error, stackTrace) {
        ErrorHandler.logError(
          error,
          stackTrace: stackTrace,
          message: 'Failed to update profile image',
        );
        overallSuccess = false;
      }
    }

    var shouldUpdateMetaProfile = false;
    final newName = (name != null && _authController.user?.name != name)
        ? name
        : null;
    final newEmail = (email != null && _authController.user?.email != email)
        ? email
        : null;
    final newProfileAvatarType =
        (profileAvatarType != null &&
            _authController.user?.profileAvatarType != profileAvatarType)
        ? profileAvatarType
        : null;
    final newAvatarSeed =
        (avatarSeed != null &&
            _authController.user?.profileAvatarSeed != avatarSeed)
        ? avatarSeed
        : null;

    if (newName != null ||
        newEmail != null ||
        newProfileAvatarType != null ||
        newAvatarSeed != null) {
      shouldUpdateMetaProfile = true;
    }

    if (shouldUpdateMetaProfile) {
      try {
        final backendUpdatedUser = await _userRepository
            .updateCurrentUserProfile(
              name: newName,
              email: newEmail,
              profileAvatarType: profileAvatarType,
              avatarSeed: avatarSeed,
            );
        finalUpdatedUser = backendUpdatedUser;
      } catch (error, stackTrace) {
        ErrorHandler.logError(
          error,
          stackTrace: stackTrace,
          message: 'Failed to update name/email',
        );
        overallSuccess = false;
      }
    }

    if (overallSuccess &&
        finalUpdatedUser != null &&
        finalUpdatedUser != _authController.user) {
      _authController.syncUser(finalUpdatedUser);
    } else if (overallSuccess &&
        (profileImage != null || shouldUpdateMetaProfile)) {
      try {
        final refreshedUser = await _userRepository.currentUser;
        _authController.syncUser(refreshedUser);
      } catch (error, stackTrace) {
        overallSuccess = false;
        ErrorHandler.logError(
          error,
          stackTrace: stackTrace,
          message: 'Failed to refresh user after profile update',
        );
      }
    }

    return overallSuccess;
  }
}
