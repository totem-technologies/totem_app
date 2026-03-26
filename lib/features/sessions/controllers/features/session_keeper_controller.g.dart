// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_keeper_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SessionKeeperController)
final sessionKeeperControllerProvider = SessionKeeperControllerFamily._();

final class SessionKeeperControllerProvider
    extends $NotifierProvider<SessionKeeperController, void> {
  SessionKeeperControllerProvider._({
    required SessionKeeperControllerFamily super.from,
    required SessionController super.argument,
  }) : super(
         retry: null,
         name: r'sessionKeeperControllerProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$sessionKeeperControllerHash();

  @override
  String toString() {
    return r'sessionKeeperControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  SessionKeeperController create() => SessionKeeperController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SessionKeeperControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$sessionKeeperControllerHash() =>
    r'e50b1821933314b112854d3419a54f51528695e5';

final class SessionKeeperControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          SessionKeeperController,
          void,
          void,
          void,
          SessionController
        > {
  SessionKeeperControllerFamily._()
    : super(
        retry: null,
        name: r'sessionKeeperControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  SessionKeeperControllerProvider call(SessionController session) =>
      SessionKeeperControllerProvider._(argument: session, from: this);

  @override
  String toString() => r'sessionKeeperControllerProvider';
}

abstract class _$SessionKeeperController extends $Notifier<void> {
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
