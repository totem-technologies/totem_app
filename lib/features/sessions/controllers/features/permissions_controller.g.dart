// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'permissions_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PermissionsController)
final permissionsControllerProvider = PermissionsControllerProvider._();

final class PermissionsControllerProvider
    extends $NotifierProvider<PermissionsController, PermissionsState> {
  PermissionsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'permissionsControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$permissionsControllerHash();

  @$internal
  @override
  PermissionsController create() => PermissionsController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PermissionsState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PermissionsState>(value),
    );
  }
}

String _$permissionsControllerHash() =>
    r'permissions_controller_generated_hash';

abstract class _$PermissionsController extends $Notifier<PermissionsState> {
  PermissionsState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<PermissionsState, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PermissionsState, void>,
              PermissionsState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
