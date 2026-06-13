// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'is_current_user_keeper_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether the logged-in user is a keeper, used to pick which variant of the
/// New Message screen to show.
///
/// Keepers are staff users, so this is derived from the `is_staff` field on
/// the current user.

@ProviderFor(isCurrentMessagingUserKeeper)
final isCurrentMessagingUserKeeperProvider =
    IsCurrentMessagingUserKeeperProvider._();

/// Whether the logged-in user is a keeper, used to pick which variant of the
/// New Message screen to show.
///
/// Keepers are staff users, so this is derived from the `is_staff` field on
/// the current user.

final class IsCurrentMessagingUserKeeperProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Whether the logged-in user is a keeper, used to pick which variant of the
  /// New Message screen to show.
  ///
  /// Keepers are staff users, so this is derived from the `is_staff` field on
  /// the current user.
  IsCurrentMessagingUserKeeperProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'isCurrentMessagingUserKeeperProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$isCurrentMessagingUserKeeperHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return isCurrentMessagingUserKeeper(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$isCurrentMessagingUserKeeperHash() =>
    r'9eab48c5d3ea3b20a9dc67aaf2c37146c7c80d3b';
