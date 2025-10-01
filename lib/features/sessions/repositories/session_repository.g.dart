// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$sessionTokenHash() => r'849b90e856cbe312b13624b9feab25626bf69a2d';

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

/// See also [sessionToken].
@ProviderFor(sessionToken)
const sessionTokenProvider = SessionTokenFamily();

/// See also [sessionToken].
class SessionTokenFamily extends Family<AsyncValue<String>> {
  /// See also [sessionToken].
  const SessionTokenFamily();

  /// See also [sessionToken].
  SessionTokenProvider call(String eventSlug) {
    return SessionTokenProvider(eventSlug);
  }

  @override
  SessionTokenProvider getProviderOverride(
    covariant SessionTokenProvider provider,
  ) {
    return call(provider.eventSlug);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'sessionTokenProvider';
}

/// See also [sessionToken].
class SessionTokenProvider extends AutoDisposeFutureProvider<String> {
  /// See also [sessionToken].
  SessionTokenProvider(String eventSlug)
    : this._internal(
        (ref) => sessionToken(ref as SessionTokenRef, eventSlug),
        from: sessionTokenProvider,
        name: r'sessionTokenProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$sessionTokenHash,
        dependencies: SessionTokenFamily._dependencies,
        allTransitiveDependencies:
            SessionTokenFamily._allTransitiveDependencies,
        eventSlug: eventSlug,
      );

  SessionTokenProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.eventSlug,
  }) : super.internal();

  final String eventSlug;

  @override
  Override overrideWith(
    FutureOr<String> Function(SessionTokenRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: SessionTokenProvider._internal(
        (ref) => create(ref as SessionTokenRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        eventSlug: eventSlug,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<String> createElement() {
    return _SessionTokenProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SessionTokenProvider && other.eventSlug == eventSlug;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, eventSlug.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin SessionTokenRef on AutoDisposeFutureProviderRef<String> {
  /// The parameter `eventSlug` of this provider.
  String get eventSlug;
}

class _SessionTokenProviderElement
    extends AutoDisposeFutureProviderElement<String>
    with SessionTokenRef {
  _SessionTokenProviderElement(super.provider);

  @override
  String get eventSlug => (origin as SessionTokenProvider).eventSlug;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
