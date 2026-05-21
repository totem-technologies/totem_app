//
// ignore_for_file: avoid_public_notifier_properties
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_core/auth/models/auth_state.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  () {
    throw UnimplementedError(
      'The AuthController provider must be overridden in the main application.',
    );
  },
  name: 'Auth Controller Provider',
);

abstract class AuthController extends Notifier<AuthState> {
  bool get isAuthenticated;
  UserSchema? get user;

  Stream<AuthState> get authStateChanges;

  Future<void> logout();
  Future<void> deleteAccount();
  Future<void> checkExistingAuth();
}
