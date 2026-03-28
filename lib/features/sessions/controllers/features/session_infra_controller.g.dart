// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_infra_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SessionInfraController)
final sessionInfraControllerProvider = SessionInfraControllerProvider._();

final class SessionInfraControllerProvider
    extends $NotifierProvider<SessionInfraController, void> {
  SessionInfraControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionInfraControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionInfraControllerHash();

  @$internal
  @override
  SessionInfraController create() => SessionInfraController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$sessionInfraControllerHash() =>
    r'2d18a94bffd173dd8960870bba6b7946e9e1b79b';

abstract class _$SessionInfraController extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
