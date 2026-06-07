import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'is_current_user_keeper_provider.g.dart';

/// Mock role flag for the New Message screen until a backend exists.
///
/// Flip the return value to `true` to preview the keeper variant of the
/// New Message screen (session participants) instead of the normal-user
/// variant (your keepers).
@riverpod
bool isCurrentMessagingUserKeeper(Ref ref) => false;
