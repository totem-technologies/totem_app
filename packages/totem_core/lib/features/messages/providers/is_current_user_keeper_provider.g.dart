// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'is_current_user_keeper_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Mock role flag for the New Message screen until a backend exists.
///
/// Flip the return value to `true` to preview the keeper variant of the
/// New Message screen (session participants) instead of the normal-user
/// variant (your keepers).

@ProviderFor(isCurrentMessagingUserKeeper)
final isCurrentMessagingUserKeeperProvider =
    IsCurrentMessagingUserKeeperProvider._();

/// Mock role flag for the New Message screen until a backend exists.
///
/// Flip the return value to `true` to preview the keeper variant of the
/// New Message screen (session participants) instead of the normal-user
/// variant (your keepers).

final class IsCurrentMessagingUserKeeperProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Mock role flag for the New Message screen until a backend exists.
  ///
  /// Flip the return value to `true` to preview the keeper variant of the
  /// New Message screen (session participants) instead of the normal-user
  /// variant (your keepers).
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
    r'3830d43efebc0eaadef7e655afc492c23906c182';
