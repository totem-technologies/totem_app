// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(mobileAuthController)
final mobileAuthControllerProvider = MobileAuthControllerProvider._();

final class MobileAuthControllerProvider
    extends
        $FunctionalProvider<
          MobileAuthController,
          MobileAuthController,
          MobileAuthController
        >
    with $Provider<MobileAuthController> {
  MobileAuthControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mobileAuthControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mobileAuthControllerHash();

  @$internal
  @override
  $ProviderElement<MobileAuthController> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MobileAuthController create(Ref ref) {
    return mobileAuthController(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MobileAuthController value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MobileAuthController>(value),
    );
  }
}

String _$mobileAuthControllerHash() =>
    r'ea4a35a5de339dc0391c7c808148a68d58c657ad';
