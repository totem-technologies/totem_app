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
    extends $NotifierProvider<SessionMessagingController, DateTime?> {
  SessionMessagingControllerProvider._({
    required SessionMessagingControllerFamily super.from,
    required SessionController super.argument,
  }) : super(
         retry: null,
         name: r'sessionMessagingControllerProvider',
         isAutoDispose: true,
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
  Override overrideWithValue(DateTime? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DateTime?>(value),
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
    r'89a720a7e4020e911c2793d25dace509c2f3011f';

final class SessionMessagingControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          SessionMessagingController,
          DateTime?,
          DateTime?,
          DateTime?,
          SessionController
        > {
  SessionMessagingControllerFamily._()
    : super(
        retry: null,
        name: r'sessionMessagingControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SessionMessagingControllerProvider call(SessionController session) =>
      SessionMessagingControllerProvider._(argument: session, from: this);

  @override
  String toString() => r'sessionMessagingControllerProvider';
}

abstract class _$SessionMessagingController extends $Notifier<DateTime?> {
  late final _$args = ref.$arg as SessionController;
  SessionController get session => _$args;

  DateTime? build(SessionController session);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<DateTime?, DateTime?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DateTime?, DateTime?>,
              DateTime?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
