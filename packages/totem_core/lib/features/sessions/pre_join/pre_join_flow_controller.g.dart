// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pre_join_flow_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PreJoinFlowController)
final preJoinFlowControllerProvider = PreJoinFlowControllerFamily._();

final class PreJoinFlowControllerProvider
    extends $NotifierProvider<PreJoinFlowController, PreJoinFlowState> {
  PreJoinFlowControllerProvider._({
    required PreJoinFlowControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'preJoinFlowControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$preJoinFlowControllerHash();

  @override
  String toString() {
    return r'preJoinFlowControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  PreJoinFlowController create() => PreJoinFlowController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PreJoinFlowState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PreJoinFlowState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PreJoinFlowControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$preJoinFlowControllerHash() =>
    r'9ffea09ae82d7aa66c6d4590808820390da06ced';

final class PreJoinFlowControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          PreJoinFlowController,
          PreJoinFlowState,
          PreJoinFlowState,
          PreJoinFlowState,
          String
        > {
  PreJoinFlowControllerFamily._()
    : super(
        retry: null,
        name: r'preJoinFlowControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  PreJoinFlowControllerProvider call(String sessionSlug) =>
      PreJoinFlowControllerProvider._(argument: sessionSlug, from: this);

  @override
  String toString() => r'preJoinFlowControllerProvider';
}

abstract class _$PreJoinFlowController extends $Notifier<PreJoinFlowState> {
  late final _$args = ref.$arg as String;
  String get sessionSlug => _$args;

  PreJoinFlowState build(String sessionSlug);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<PreJoinFlowState, PreJoinFlowState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PreJoinFlowState, PreJoinFlowState>,
              PreJoinFlowState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
