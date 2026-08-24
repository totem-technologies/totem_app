// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SessionController)
final sessionControllerProvider = SessionControllerFamily._();

final class SessionControllerProvider
    extends $NotifierProvider<SessionController, SessionRoomState> {
  SessionControllerProvider._({
    required SessionControllerFamily super.from,
    required SessionOptions super.argument,
  }) : super(
         retry: null,
         name: r'sessionControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$sessionControllerHash();

  @override
  String toString() {
    return r'sessionControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  SessionController create() => SessionController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionRoomState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionRoomState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SessionControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$sessionControllerHash() => r'63a0527cdf7cf1dd02a047ea67e4c73c78330b4b';

final class SessionControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          SessionController,
          SessionRoomState,
          SessionRoomState,
          SessionRoomState,
          SessionOptions
        > {
  SessionControllerFamily._()
    : super(
        retry: null,
        name: r'sessionControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SessionControllerProvider call(SessionOptions options) =>
      SessionControllerProvider._(argument: options, from: this);

  @override
  String toString() => r'sessionControllerProvider';
}

abstract class _$SessionController extends $Notifier<SessionRoomState> {
  late final _$args = ref.$arg as SessionOptions;
  SessionOptions get options => _$args;

  SessionRoomState build(SessionOptions options);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SessionRoomState, SessionRoomState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SessionRoomState, SessionRoomState>,
              SessionRoomState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
