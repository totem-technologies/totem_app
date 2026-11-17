// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_messaging_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Thin compatibility facade. Feature owners hold state and implement protocols.

@ProviderFor(SessionMessagingController)
final sessionMessagingControllerProvider = SessionMessagingControllerFamily._();

/// Thin compatibility facade. Feature owners hold state and implement protocols.
final class SessionMessagingControllerProvider
    extends $NotifierProvider<SessionMessagingController, void> {
  /// Thin compatibility facade. Feature owners hold state and implement protocols.
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
    r'2eb3c885e2d25c88bc1ac50a899ae3d7f83bf499';

/// Thin compatibility facade. Feature owners hold state and implement protocols.

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
        isAutoDispose: true,
      );

  /// Thin compatibility facade. Feature owners hold state and implement protocols.

  SessionMessagingControllerProvider call(SessionController session) =>
      SessionMessagingControllerProvider._(argument: session, from: this);

  @override
  String toString() => r'sessionMessagingControllerProvider';
}

/// Thin compatibility facade. Feature owners hold state and implement protocols.

abstract class _$SessionMessagingController extends $Notifier<void> {
  late final _$args = ref.$arg as SessionController;
  SessionController get session => _$args;

  void build(SessionController session);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
