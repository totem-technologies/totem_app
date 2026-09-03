import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';

part 'is_current_user_keeper_provider.g.dart';

/// Whether the logged-in user is a keeper, used to pick which variant of the
/// New Message screen to show.
///
/// Keepers are staff users, so this is derived from the `is_staff` field on
/// the current user.
@riverpod
bool isCurrentMessagingUserKeeper(Ref ref) {
  final authState = ref.watch(authControllerProvider);
  return authState.user?.isStaff ?? false;
}
