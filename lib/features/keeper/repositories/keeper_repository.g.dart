// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'keeper_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$keeperProfileHash() => r'8a341bc17444b8be1079e1cd73fb050ac25159d0';

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
  KeeperProfileProvider call(String username) {
    return KeeperProfileProvider(username);
  }

  @override
  KeeperProfileProvider getProviderOverride(
    covariant KeeperProfileProvider provider,
  ) {
    return call(provider.username);
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
  KeeperProfileProvider(String username)
    : this._internal(
        (ref) => keeperProfile(ref as KeeperProfileRef, username),
        from: keeperProfileProvider,
        name: r'keeperProfileProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$keeperProfileHash,
        dependencies: KeeperProfileFamily._dependencies,
        allTransitiveDependencies:
            KeeperProfileFamily._allTransitiveDependencies,
        username: username,
      );

  KeeperProfileProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.username,
  }) : super.internal();

  final String username;

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
        username: username,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<KeeperProfileSchema> createElement() {
    return _KeeperProfileProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is KeeperProfileProvider && other.username == username;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, username.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin KeeperProfileRef on AutoDisposeFutureProviderRef<KeeperProfileSchema> {
  /// The parameter `username` of this provider.
  String get username;
}

class _KeeperProfileProviderElement
    extends AutoDisposeFutureProviderElement<KeeperProfileSchema>
    with KeeperProfileRef {
  _KeeperProfileProviderElement(super.provider);

  @override
  String get username => (origin as KeeperProfileProvider).username;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
