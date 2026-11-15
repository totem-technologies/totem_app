// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_transport_factory_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(sessionTransportFactory)
final sessionTransportFactoryProvider = SessionTransportFactoryFamily._();

final class SessionTransportFactoryProvider
    extends
        $FunctionalProvider<
          SessionTransportFactory,
          SessionTransportFactory,
          SessionTransportFactory
        >
    with $Provider<SessionTransportFactory> {
  SessionTransportFactoryProvider._({
    required SessionTransportFactoryFamily super.from,
    required SessionOptions super.argument,
  }) : super(
         retry: null,
         name: r'sessionTransportFactoryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$sessionTransportFactoryHash();

  @override
  String toString() {
    return r'sessionTransportFactoryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<SessionTransportFactory> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SessionTransportFactory create(Ref ref) {
    final argument = this.argument as SessionOptions;
    return sessionTransportFactory(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionTransportFactory value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionTransportFactory>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SessionTransportFactoryProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$sessionTransportFactoryHash() =>
    r'990787d704dd9d14a238b2de3cdd5abb1f7238b9';

final class SessionTransportFactoryFamily extends $Family
    with $FunctionalFamilyOverride<SessionTransportFactory, SessionOptions> {
  SessionTransportFactoryFamily._()
    : super(
        retry: null,
        name: r'sessionTransportFactoryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SessionTransportFactoryProvider call(SessionOptions options) =>
      SessionTransportFactoryProvider._(argument: options, from: this);

  @override
  String toString() => r'sessionTransportFactoryProvider';
}
