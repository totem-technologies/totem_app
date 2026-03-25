// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_infra_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SessionInfraController)
final sessionInfraControllerProvider = SessionInfraControllerFamily._();

final class SessionInfraControllerProvider
    extends $NotifierProvider<SessionInfraController, void> {
  SessionInfraControllerProvider._({
    required SessionInfraControllerFamily super.from,
    required SessionOptions super.argument,
  }) : super(
         retry: null,
         name: r'sessionInfraControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$sessionInfraControllerHash();

  @override
  String toString() {
    return r'sessionInfraControllerProvider'
        ''
        '($argument)';
  }

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

  @override
  bool operator ==(Object other) {
    return other is SessionInfraControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$sessionInfraControllerHash() =>
    r'fbf92abf1903001afb017537cccdf03b69703ef1';

final class SessionInfraControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          SessionInfraController,
          void,
          void,
          void,
          SessionOptions
        > {
  SessionInfraControllerFamily._()
    : super(
        retry: null,
        name: r'sessionInfraControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SessionInfraControllerProvider call(SessionOptions options) =>
      SessionInfraControllerProvider._(argument: options, from: this);

  @override
  String toString() => r'sessionInfraControllerProvider';
}

abstract class _$SessionInfraController extends $Notifier<void> {
  late final _$args = ref.$arg as SessionOptions;
  SessionOptions get options => _$args;

  void build(SessionOptions options);
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
