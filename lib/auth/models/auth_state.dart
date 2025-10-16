import 'package:flutter/foundation.dart';
import 'package:totem_app/api/models/user_schema.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  awaitingVerification,
  error,
}

@immutable
class AuthState {
  const AuthState({required this.status, this.user, this.email, this.error});

  factory AuthState.initial() {
    return const AuthState(status: AuthStatus.initial);
  }

  factory AuthState.loading() {
    return const AuthState(status: AuthStatus.loading);
  }

  factory AuthState.authenticated({required UserSchema user}) {
    return AuthState(
      status: AuthStatus.authenticated,
      user: user,
      email: user.email,
    );
  }

  factory AuthState.unauthenticated() {
    return const AuthState(status: AuthStatus.unauthenticated);
  }

  factory AuthState.awaitingVerification({required String email}) {
    return AuthState(status: AuthStatus.awaitingVerification, email: email);
  }

  factory AuthState.error(String message) {
    return AuthState(status: AuthStatus.error, error: message);
  }

  final AuthStatus status;
  final UserSchema? user;
  final String? email;
  final String? error;

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
    final buffer = StringBuffer('AuthState {')..write('status: $status');
    if (user != null) {
      buffer.write(', user: $user');
    }
    if (email != null) {
      buffer.write(', email: $email');
    }
    if (error != null) {
      buffer.write(', error: $error');
    }
    buffer.write('}');
    return buffer.toString();
  }
}
