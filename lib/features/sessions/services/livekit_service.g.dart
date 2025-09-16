// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'livekit_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$sessionServiceHash() => r'2ec1faf7c1fd4818263a7990eb869f90d19cd6e4';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// See also [sessionService].
@ProviderFor(sessionService)
const sessionServiceProvider = SessionServiceFamily();

/// See also [sessionService].
class SessionServiceFamily extends Family<LiveKitService> {
  /// See also [sessionService].
  const SessionServiceFamily();

  /// See also [sessionService].
  SessionServiceProvider call(SessionOptions options) {
    return SessionServiceProvider(options);
  }

  @override
  SessionServiceProvider getProviderOverride(
    covariant SessionServiceProvider provider,
  ) {
    return call(provider.options);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'sessionServiceProvider';
}

/// See also [sessionService].
class SessionServiceProvider extends AutoDisposeProvider<LiveKitService> {
  /// See also [sessionService].
  SessionServiceProvider(SessionOptions options)
    : this._internal(
        (ref) => sessionService(ref as SessionServiceRef, options),
        from: sessionServiceProvider,
        name: r'sessionServiceProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$sessionServiceHash,
        dependencies: SessionServiceFamily._dependencies,
        allTransitiveDependencies:
            SessionServiceFamily._allTransitiveDependencies,
        options: options,
      );

  SessionServiceProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.options,
  }) : super.internal();

  final SessionOptions options;

  @override
  Override overrideWith(
    LiveKitService Function(SessionServiceRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: SessionServiceProvider._internal(
        (ref) => create(ref as SessionServiceRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        options: options,
      ),
    );
  }

  @override
  AutoDisposeProviderElement<LiveKitService> createElement() {
    return _SessionServiceProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SessionServiceProvider && other.options == options;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, options.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin SessionServiceRef on AutoDisposeProviderRef<LiveKitService> {
  /// The parameter `options` of this provider.
  SessionOptions get options;
}

class _SessionServiceProviderElement
    extends AutoDisposeProviderElement<LiveKitService>
    with SessionServiceRef {
  _SessionServiceProviderElement(super.provider);

  @override
  SessionOptions get options => (origin as SessionServiceProvider).options;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
