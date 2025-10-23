// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'livekit_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$liveKitServiceHash() => r'c92e61957b4ced1614e2a4184ee9e8eee5d50a82';

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

abstract class _$LiveKitService
    extends BuildlessAutoDisposeNotifier<LiveKitState> {
  late final SessionOptions options;

  LiveKitState build(SessionOptions options);
}

/// See also [LiveKitService].
@ProviderFor(LiveKitService)
const liveKitServiceProvider = LiveKitServiceFamily();

/// See also [LiveKitService].
class LiveKitServiceFamily extends Family<LiveKitState> {
  /// See also [LiveKitService].
  const LiveKitServiceFamily();

  /// See also [LiveKitService].
  LiveKitServiceProvider call(SessionOptions options) {
    return LiveKitServiceProvider(options);
  }

  @override
  LiveKitServiceProvider getProviderOverride(
    covariant LiveKitServiceProvider provider,
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
  String? get name => r'liveKitServiceProvider';
}

/// See also [LiveKitService].
class LiveKitServiceProvider
    extends AutoDisposeNotifierProviderImpl<LiveKitService, LiveKitState> {
  /// See also [LiveKitService].
  LiveKitServiceProvider(SessionOptions options)
    : this._internal(
        () => LiveKitService()..options = options,
        from: liveKitServiceProvider,
        name: r'liveKitServiceProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$liveKitServiceHash,
        dependencies: LiveKitServiceFamily._dependencies,
        allTransitiveDependencies:
            LiveKitServiceFamily._allTransitiveDependencies,
        options: options,
      );

  LiveKitServiceProvider._internal(
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
  LiveKitState runNotifierBuild(covariant LiveKitService notifier) {
    return notifier.build(options);
  }

  @override
  Override overrideWith(LiveKitService Function() create) {
    return ProviderOverride(
      origin: this,
      override: LiveKitServiceProvider._internal(
        () => create()..options = options,
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
  AutoDisposeNotifierProviderElement<LiveKitService, LiveKitState>
  createElement() {
    return _LiveKitServiceProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is LiveKitServiceProvider && other.options == options;
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
mixin LiveKitServiceRef on AutoDisposeNotifierProviderRef<LiveKitState> {
  /// The parameter `options` of this provider.
  SessionOptions get options;
}

class _LiveKitServiceProviderElement
    extends AutoDisposeNotifierProviderElement<LiveKitService, LiveKitState>
    with LiveKitServiceRef {
  _LiveKitServiceProviderElement(super.provider);

  @override
  SessionOptions get options => (origin as LiveKitServiceProvider).options;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
