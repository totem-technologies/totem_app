// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_messaging_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SessionMessagingController)
final sessionMessagingControllerProvider = SessionMessagingControllerFamily._();

final class SessionMessagingControllerProvider
    extends $NotifierProvider<SessionMessagingController, void> {
  SessionMessagingControllerProvider._({
    required SessionMessagingControllerFamily super.from,
    required SessionController super.argument,
  }) : super(
         retry: null,
         name: r'sessionMessagingControllerProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$sessionMessagingControllerHash();

  @override
  String toString() {
    return r'sessionMessagingControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  SessionMessagingController create() => SessionMessagingController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SessionMessagingControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$sessionMessagingControllerHash() =>
    r'55198320aba0e98a5bacc7655a07ed3710f98a69';

final class SessionMessagingControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          SessionMessagingController,
          void,
          void,
          void,
          SessionController
        > {
  SessionMessagingControllerFamily._()
    : super(
        retry: null,
        name: r'sessionMessagingControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  SessionMessagingControllerProvider call(SessionController session) =>
      SessionMessagingControllerProvider._(argument: session, from: this);

  @override
  String toString() => r'sessionMessagingControllerProvider';
}

abstract class _$SessionMessagingController extends $Notifier<void> {
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
