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
    extends $NotifierProvider<SessionDeviceController, void> {
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
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
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
    r'2c9f768706a19e186852781e4f9de26bed78c9b3';

final class SessionDeviceControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          SessionDeviceController,
          void,
          void,
          void,
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

abstract class _$SessionDeviceController extends $Notifier<void> {
  late final _$args = ref.$arg as SessionController;
  SessionController get session => _$args;

  void build(SessionController session);
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
    element.handleCreate(ref, () => build(_$args));
  }
}
