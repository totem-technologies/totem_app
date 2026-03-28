// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_device_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SessionDeviceController)
final sessionDeviceControllerProvider = SessionDeviceControllerFamily._();

final class SessionDeviceControllerProvider
    extends $NotifierProvider<SessionDeviceController, SessionDeviceState> {
  SessionDeviceControllerProvider._({
    required SessionDeviceControllerFamily super.from,
    required SessionController super.argument,
  }) : super(
         retry: null,
         name: r'sessionDeviceControllerProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$sessionDeviceControllerHash();

  @override
  String toString() {
    return r'sessionDeviceControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  SessionDeviceController create() => SessionDeviceController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionDeviceState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionDeviceState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SessionDeviceControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$sessionDeviceControllerHash() =>
    r'7d8269157419c7ef40c73e6592e76cc91830888c';

final class SessionDeviceControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          SessionDeviceController,
          SessionDeviceState,
          SessionDeviceState,
          SessionDeviceState,
          SessionController
        > {
  SessionDeviceControllerFamily._()
    : super(
        retry: null,
        name: r'sessionDeviceControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  SessionDeviceControllerProvider call(SessionController session) =>
      SessionDeviceControllerProvider._(argument: session, from: this);

  @override
  String toString() => r'sessionDeviceControllerProvider';
}

abstract class _$SessionDeviceController extends $Notifier<SessionDeviceState> {
  late final _$args = ref.$arg as SessionController;
  SessionController get session => _$args;

  SessionDeviceState build(SessionController session);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<SessionDeviceState, SessionDeviceState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SessionDeviceState, SessionDeviceState>,
              SessionDeviceState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
