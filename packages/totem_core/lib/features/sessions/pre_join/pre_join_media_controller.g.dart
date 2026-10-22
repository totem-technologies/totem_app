// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pre_join_media_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The pre-join preview's camera and microphone.
///
/// Both devices start wanted. A [CaptureLoop] decides when each is captured:
/// on native once its permission is granted, so the OS prompt only follows
/// the user (X2); on web straight away, since capture is the request (WS2).
/// A permission change, the tab's visibility and the user's toggles all just
/// re-run the loop. Every capture goes through one queue, because cold-start
/// Safari can't take overlapping requests.

@ProviderFor(PreJoinMediaController)
final preJoinMediaControllerProvider = PreJoinMediaControllerFamily._();

/// The pre-join preview's camera and microphone.
///
/// Both devices start wanted. A [CaptureLoop] decides when each is captured:
/// on native once its permission is granted, so the OS prompt only follows
/// the user (X2); on web straight away, since capture is the request (WS2).
/// A permission change, the tab's visibility and the user's toggles all just
/// re-run the loop. Every capture goes through one queue, because cold-start
/// Safari can't take overlapping requests.
final class PreJoinMediaControllerProvider
    extends $NotifierProvider<PreJoinMediaController, PreJoinMediaState> {
  /// The pre-join preview's camera and microphone.
  ///
  /// Both devices start wanted. A [CaptureLoop] decides when each is captured:
  /// on native once its permission is granted, so the OS prompt only follows
  /// the user (X2); on web straight away, since capture is the request (WS2).
  /// A permission change, the tab's visibility and the user's toggles all just
  /// re-run the loop. Every capture goes through one queue, because cold-start
  /// Safari can't take overlapping requests.
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
    r'f0e0a022d570959632ec6bb6975052e56fb70521';

/// The pre-join preview's camera and microphone.
///
/// Both devices start wanted. A [CaptureLoop] decides when each is captured:
/// on native once its permission is granted, so the OS prompt only follows
/// the user (X2); on web straight away, since capture is the request (WS2).
/// A permission change, the tab's visibility and the user's toggles all just
/// re-run the loop. Every capture goes through one queue, because cold-start
/// Safari can't take overlapping requests.

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

  /// The pre-join preview's camera and microphone.
  ///
  /// Both devices start wanted. A [CaptureLoop] decides when each is captured:
  /// on native once its permission is granted, so the OS prompt only follows
  /// the user (X2); on web straight away, since capture is the request (WS2).
  /// A permission change, the tab's visibility and the user's toggles all just
  /// re-run the loop. Every capture goes through one queue, because cold-start
  /// Safari can't take overlapping requests.

  PreJoinMediaControllerProvider call(String sessionSlug) =>
      PreJoinMediaControllerProvider._(argument: sessionSlug, from: this);

  @override
  String toString() => r'preJoinMediaControllerProvider';
}

/// The pre-join preview's camera and microphone.
///
/// Both devices start wanted. A [CaptureLoop] decides when each is captured:
/// on native once its permission is granted, so the OS prompt only follows
/// the user (X2); on web straight away, since capture is the request (WS2).
/// A permission change, the tab's visibility and the user's toggles all just
/// re-run the loop. Every capture goes through one queue, because cold-start
/// Safari can't take overlapping requests.

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
