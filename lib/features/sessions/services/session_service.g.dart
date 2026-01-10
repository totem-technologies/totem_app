// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(Session)
final sessionProvider = SessionFamily._();

final class SessionProvider
    extends $NotifierProvider<Session, SessionRoomState> {
  SessionProvider._({
    required SessionFamily super.from,
    required SessionOptions super.argument,
  }) : super(
         retry: null,
         name: r'sessionProvider',
         isAutoDispose: true,
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
  Session create() => Session();

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

String _$sessionHash() => r'5a2d99daf6a5d32343487635f45ebf8f4c8122a9';

final class SessionFamily extends $Family
    with
        $ClassFamilyOverride<
          Session,
          SessionRoomState,
          SessionRoomState,
          SessionRoomState,
          SessionOptions
        > {
  SessionFamily._()
    : super(
        retry: null,
        name: r'sessionProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SessionProvider call(SessionOptions options) =>
      SessionProvider._(argument: options, from: this);

  @override
  String toString() => r'sessionProvider';
}

abstract class _$Session extends $Notifier<SessionRoomState> {
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
