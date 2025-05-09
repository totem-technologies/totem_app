import 'package:flutter/foundation.dart';
import 'package:totem_app/api/models/user_schema.dart';

/// Possible authentication statuses
enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  awaitingVerification,
  error,
}

/// Class to represent the current authentication state
@immutable
class AuthState {
  const AuthState({required this.status, this.user, this.email, this.error});

  /// Factory for initial state
  factory AuthState.initial() {
    return const AuthState(status: AuthStatus.initial);
  }

  /// Factory for loading state
  factory AuthState.loading() {
    return const AuthState(status: AuthStatus.loading);
  }

  /// Factory for authenticated state
  factory AuthState.authenticated({required UserSchema user}) {
    return AuthState(status: AuthStatus.authenticated, user: user);
  }

  /// Factory for unauthenticated state
  factory AuthState.unauthenticated() {
    return const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Factory for awaiting verification state (after requesting magic link)
  factory AuthState.awaitingVerification({required String email}) {
    return AuthState(status: AuthStatus.awaitingVerification, email: email);
  }

  /// Factory for error state
  factory AuthState.error(String message) {
    return AuthState(status: AuthStatus.error, error: message);
  }
  final AuthStatus status;
  final UserSchema? user;
  final String? email;
  final String? error;

  /// Create a copy of this state with modified fields
  AuthState copyWith({
    AuthStatus? status,
    UserSchema? user,
    String? email,
    String? error,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      email: email ?? this.email,
      error: error ?? this.error,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AuthState &&
        other.status == status &&
        other.user == user &&
        other.email == email &&
        other.error == error;
  }

  @override
  int get hashCode {
    return status.hashCode ^ user.hashCode ^ email.hashCode ^ error.hashCode;
  }

  @override
  String toString() {
    return 'AuthState('
        'status: $status, user: ${user?.email}, email: $email, error: $error'
        ')';
  }
}
