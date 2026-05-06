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
    extends $AsyncNotifierProvider<PermissionsController, PermissionsState> {
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
}

String _$permissionsControllerHash() =>
    r'e600563a9a09e2948af7579936615ea151a06d20';

abstract class _$PermissionsController
    extends $AsyncNotifier<PermissionsState> {
  FutureOr<PermissionsState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<PermissionsState>, PermissionsState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<PermissionsState>, PermissionsState>,
              AsyncValue<PermissionsState>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
