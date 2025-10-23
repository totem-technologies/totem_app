// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'keeper_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$keeperProfileHash() => r'a5d935e4d297af37e1b4c4839da183a91ef4ca2e';

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

/// See also [keeperProfile].
@ProviderFor(keeperProfile)
const keeperProfileProvider = KeeperProfileFamily();

/// See also [keeperProfile].
class KeeperProfileFamily extends Family<AsyncValue<KeeperProfileSchema>> {
  /// See also [keeperProfile].
  const KeeperProfileFamily();

  /// See also [keeperProfile].
  KeeperProfileProvider call(String slug) {
    return KeeperProfileProvider(slug);
  }

  @override
  KeeperProfileProvider getProviderOverride(
    covariant KeeperProfileProvider provider,
  ) {
    return call(provider.slug);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'keeperProfileProvider';
}

/// See also [keeperProfile].
class KeeperProfileProvider
    extends AutoDisposeFutureProvider<KeeperProfileSchema> {
  /// See also [keeperProfile].
  KeeperProfileProvider(String slug)
    : this._internal(
        (ref) => keeperProfile(ref as KeeperProfileRef, slug),
        from: keeperProfileProvider,
        name: r'keeperProfileProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$keeperProfileHash,
        dependencies: KeeperProfileFamily._dependencies,
        allTransitiveDependencies:
            KeeperProfileFamily._allTransitiveDependencies,
        slug: slug,
      );

  KeeperProfileProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.slug,
  }) : super.internal();

  final String slug;

  @override
  Override overrideWith(
    FutureOr<KeeperProfileSchema> Function(KeeperProfileRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: KeeperProfileProvider._internal(
        (ref) => create(ref as KeeperProfileRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        slug: slug,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<KeeperProfileSchema> createElement() {
    return _KeeperProfileProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is KeeperProfileProvider && other.slug == slug;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, slug.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin KeeperProfileRef on AutoDisposeFutureProviderRef<KeeperProfileSchema> {
  /// The parameter `slug` of this provider.
  String get slug;
}

class _KeeperProfileProviderElement
    extends AutoDisposeFutureProviderElement<KeeperProfileSchema>
    with KeeperProfileRef {
  _KeeperProfileProviderElement(super.provider);

  @override
  String get slug => (origin as KeeperProfileProvider).slug;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
