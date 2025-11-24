// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'livekit_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(LiveKitService)
const liveKitServiceProvider = LiveKitServiceFamily._();

final class LiveKitServiceProvider
    extends $NotifierProvider<LiveKitService, LiveKitState> {
  const LiveKitServiceProvider._({
    required LiveKitServiceFamily super.from,
    required SessionOptions super.argument,
  }) : super(
         retry: null,
         name: r'liveKitServiceProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$liveKitServiceHash();

  @override
  String toString() {
    return r'liveKitServiceProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  LiveKitService create() => LiveKitService();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LiveKitState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LiveKitState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is LiveKitServiceProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$liveKitServiceHash() => r'3f4b615782d76794754ac01f69544c48273c37c8';

final class LiveKitServiceFamily extends $Family
    with
        $ClassFamilyOverride<
          LiveKitService,
          LiveKitState,
          LiveKitState,
          LiveKitState,
          SessionOptions
        > {
  const LiveKitServiceFamily._()
    : super(
        retry: null,
        name: r'liveKitServiceProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  LiveKitServiceProvider call(SessionOptions options) =>
      LiveKitServiceProvider._(argument: options, from: this);

  @override
  String toString() => r'liveKitServiceProvider';
}

abstract class _$LiveKitService extends $Notifier<LiveKitState> {
  late final _$args = ref.$arg as SessionOptions;
  SessionOptions get options => _$args;

  LiveKitState build(SessionOptions options);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<LiveKitState, LiveKitState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<LiveKitState, LiveKitState>,
              LiveKitState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
