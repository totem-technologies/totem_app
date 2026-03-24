// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_service.dart';

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

String _$sessionControllerHash() => r'f720446a27a6aa9dbfd6f1f2e38c328223372a79';

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
  void runBuild() {
    final ref = this.ref as $Ref<SessionRoomState, SessionRoomState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SessionRoomState, SessionRoomState>,
              SessionRoomState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}

@ProviderFor(session)
final sessionProvider = SessionFamily._();

final class SessionProvider
    extends
        $FunctionalProvider<
          SessionRoomState,
          SessionRoomState,
          SessionRoomState
        >
    with $Provider<SessionRoomState> {
  SessionProvider._({
    required SessionFamily super.from,
    required SessionOptions super.argument,
  }) : super(
         retry: null,
         name: r'sessionProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$sessionHash();

  @override
  String toString() {
    return r'sessionProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<SessionRoomState> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SessionRoomState create(Ref ref) {
    final argument = this.argument as SessionOptions;
    return session(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionRoomState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionRoomState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SessionProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$sessionHash() => r'35dc3013679bce73810ca76eac0830f12a88ab49';

final class SessionFamily extends $Family
    with $FunctionalFamilyOverride<SessionRoomState, SessionOptions> {
  SessionFamily._()
    : super(
        retry: null,
        name: r'sessionProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  SessionProvider call(SessionOptions options) =>
      SessionProvider._(argument: options, from: this);

  @override
  String toString() => r'sessionProvider';
}
