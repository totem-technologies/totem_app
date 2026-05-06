import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Collection of functions to guard routes based on authentication state
/// or other conditions

/// Guard for routes that require authentication
/// Use with the redirect parameter in GoRoute
bool requireAuthGuard(
  BuildContext context,
  GoRouterState state,
  bool isAuthenticated,
) {
  if (!isAuthenticated) {
    // Redirect to login if not authenticated
    return true;
  }
  return false;
}

/// Guard for routes that require onboarding to be completed
/// Use with the redirect parameter in GoRoute
bool requireOnboardingGuard(
  BuildContext context,
  GoRouterState state,
  bool isAuthenticated,
  bool isOnboardingCompleted,
) {
  if (isAuthenticated && !isOnboardingCompleted) {
    // Redirect to onboarding if authenticated but onboarding not completed
    return true;
  }
  return false;
}

/// Guard for routes that require keeper role
/// Use with the redirect parameter in GoRoute
bool requireKeeperRoleGuard(
  BuildContext context,
  GoRouterState state,
  bool isKeeper,
) {
  if (!isKeeper) {
    // Redirect to an unauthorized page or home
    return true;
  }
  return false;
}
