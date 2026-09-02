// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pre_join_media_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PreJoinMediaController)
final preJoinMediaControllerProvider = PreJoinMediaControllerFamily._();

final class PreJoinMediaControllerProvider
    extends $NotifierProvider<PreJoinMediaController, PreJoinMediaState> {
  PreJoinMediaControllerProvider._({
    required PreJoinMediaControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'preJoinMediaControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$preJoinMediaControllerHash();

  @override
  String toString() {
    return r'preJoinMediaControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  PreJoinMediaController create() => PreJoinMediaController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PreJoinMediaState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PreJoinMediaState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PreJoinMediaControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$preJoinMediaControllerHash() =>
    r'141c32083126417ddbf49389ac31feff723c08b0';

final class PreJoinMediaControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          PreJoinMediaController,
          PreJoinMediaState,
          PreJoinMediaState,
          PreJoinMediaState,
          String
        > {
  PreJoinMediaControllerFamily._()
    : super(
        retry: null,
        name: r'preJoinMediaControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  PreJoinMediaControllerProvider call(String sessionSlug) =>
      PreJoinMediaControllerProvider._(argument: sessionSlug, from: this);

  @override
  String toString() => r'preJoinMediaControllerProvider';
}

abstract class _$PreJoinMediaController extends $Notifier<PreJoinMediaState> {
  late final _$args = ref.$arg as String;
  String get sessionSlug => _$args;

  PreJoinMediaState build(String sessionSlug);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<PreJoinMediaState, PreJoinMediaState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PreJoinMediaState, PreJoinMediaState>,
              PreJoinMediaState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
