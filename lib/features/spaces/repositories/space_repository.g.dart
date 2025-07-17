// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'space_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$listSpacesHash() => r'5e4af02f508d872c95e913011e610e8a394b548d';

/// See also [listSpaces].
@ProviderFor(listSpaces)
final listSpacesProvider =
    AutoDisposeFutureProvider<List<SpaceDetailSchema>>.internal(
      listSpaces,
      name: r'listSpacesProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$listSpacesHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ListSpacesRef = AutoDisposeFutureProviderRef<List<SpaceDetailSchema>>;
String _$eventHash() => r'45c7d390bcdc6683294c1783234cff99bc4c79ab';

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

/// See also [event].
@ProviderFor(event)
const eventProvider = EventFamily();

/// See also [event].
class EventFamily extends Family<AsyncValue<EventDetailSchema>> {
  /// See also [event].
  const EventFamily();

  /// See also [event].
  EventProvider call(String eventSlug) {
    return EventProvider(eventSlug);
  }

  @override
  EventProvider getProviderOverride(covariant EventProvider provider) {
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
  String? get name => r'eventProvider';
}

/// See also [event].
class EventProvider extends AutoDisposeFutureProvider<EventDetailSchema> {
  /// See also [event].
  EventProvider(String eventSlug)
    : this._internal(
        (ref) => event(ref as EventRef, eventSlug),
        from: eventProvider,
        name: r'eventProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$eventHash,
        dependencies: EventFamily._dependencies,
        allTransitiveDependencies: EventFamily._allTransitiveDependencies,
        eventSlug: eventSlug,
      );

  EventProvider._internal(
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
    FutureOr<EventDetailSchema> Function(EventRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: EventProvider._internal(
        (ref) => create(ref as EventRef),
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
  AutoDisposeFutureProviderElement<EventDetailSchema> createElement() {
    return _EventProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is EventProvider && other.eventSlug == eventSlug;
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
mixin EventRef on AutoDisposeFutureProviderRef<EventDetailSchema> {
  /// The parameter `eventSlug` of this provider.
  String get eventSlug;
}

class _EventProviderElement
    extends AutoDisposeFutureProviderElement<EventDetailSchema>
    with EventRef {
  _EventProviderElement(super.provider);

  @override
  String get eventSlug => (origin as EventProvider).eventSlug;
}

String _$listSubscribedSpacesHash() =>
    r'2b4b00c814f4fdd7b2ca99b6433d5fb8ff7aee5e';

/// See also [listSubscribedSpaces].
@ProviderFor(listSubscribedSpaces)
final listSubscribedSpacesProvider =
    AutoDisposeFutureProvider<List<SpaceSchema>>.internal(
      listSubscribedSpaces,
      name: r'listSubscribedSpacesProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$listSubscribedSpacesHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ListSubscribedSpacesRef =
    AutoDisposeFutureProviderRef<List<SpaceSchema>>;
String _$subscribeToSpaceHash() => r'1bf0ba8b30966e2e5dce99fab5ddc30cf8bb19bf';

/// See also [subscribeToSpace].
@ProviderFor(subscribeToSpace)
const subscribeToSpaceProvider = SubscribeToSpaceFamily();

/// See also [subscribeToSpace].
class SubscribeToSpaceFamily extends Family<AsyncValue<bool>> {
  /// See also [subscribeToSpace].
  const SubscribeToSpaceFamily();

  /// See also [subscribeToSpace].
  SubscribeToSpaceProvider call(String spaceSlug) {
    return SubscribeToSpaceProvider(spaceSlug);
  }

  @override
  SubscribeToSpaceProvider getProviderOverride(
    covariant SubscribeToSpaceProvider provider,
  ) {
    return call(provider.spaceSlug);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'subscribeToSpaceProvider';
}

/// See also [subscribeToSpace].
class SubscribeToSpaceProvider extends AutoDisposeFutureProvider<bool> {
  /// See also [subscribeToSpace].
  SubscribeToSpaceProvider(String spaceSlug)
    : this._internal(
        (ref) => subscribeToSpace(ref as SubscribeToSpaceRef, spaceSlug),
        from: subscribeToSpaceProvider,
        name: r'subscribeToSpaceProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$subscribeToSpaceHash,
        dependencies: SubscribeToSpaceFamily._dependencies,
        allTransitiveDependencies:
            SubscribeToSpaceFamily._allTransitiveDependencies,
        spaceSlug: spaceSlug,
      );

  SubscribeToSpaceProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.spaceSlug,
  }) : super.internal();

  final String spaceSlug;

  @override
  Override overrideWith(
    FutureOr<bool> Function(SubscribeToSpaceRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: SubscribeToSpaceProvider._internal(
        (ref) => create(ref as SubscribeToSpaceRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        spaceSlug: spaceSlug,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<bool> createElement() {
    return _SubscribeToSpaceProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SubscribeToSpaceProvider && other.spaceSlug == spaceSlug;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, spaceSlug.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin SubscribeToSpaceRef on AutoDisposeFutureProviderRef<bool> {
  /// The parameter `spaceSlug` of this provider.
  String get spaceSlug;
}

class _SubscribeToSpaceProviderElement
    extends AutoDisposeFutureProviderElement<bool>
    with SubscribeToSpaceRef {
  _SubscribeToSpaceProviderElement(super.provider);

  @override
  String get spaceSlug => (origin as SubscribeToSpaceProvider).spaceSlug;
}

String _$unsubscribeFromSpaceHash() =>
    r'9964930d5f0e388324fa3d1f85402123883c836e';

/// See also [unsubscribeFromSpace].
@ProviderFor(unsubscribeFromSpace)
const unsubscribeFromSpaceProvider = UnsubscribeFromSpaceFamily();

/// See also [unsubscribeFromSpace].
class UnsubscribeFromSpaceFamily extends Family<AsyncValue<bool>> {
  /// See also [unsubscribeFromSpace].
  const UnsubscribeFromSpaceFamily();

  /// See also [unsubscribeFromSpace].
  UnsubscribeFromSpaceProvider call(String spaceSlug) {
    return UnsubscribeFromSpaceProvider(spaceSlug);
  }

  @override
  UnsubscribeFromSpaceProvider getProviderOverride(
    covariant UnsubscribeFromSpaceProvider provider,
  ) {
    return call(provider.spaceSlug);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'unsubscribeFromSpaceProvider';
}

/// See also [unsubscribeFromSpace].
class UnsubscribeFromSpaceProvider extends AutoDisposeFutureProvider<bool> {
  /// See also [unsubscribeFromSpace].
  UnsubscribeFromSpaceProvider(String spaceSlug)
    : this._internal(
        (ref) =>
            unsubscribeFromSpace(ref as UnsubscribeFromSpaceRef, spaceSlug),
        from: unsubscribeFromSpaceProvider,
        name: r'unsubscribeFromSpaceProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$unsubscribeFromSpaceHash,
        dependencies: UnsubscribeFromSpaceFamily._dependencies,
        allTransitiveDependencies:
            UnsubscribeFromSpaceFamily._allTransitiveDependencies,
        spaceSlug: spaceSlug,
      );

  UnsubscribeFromSpaceProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.spaceSlug,
  }) : super.internal();

  final String spaceSlug;

  @override
  Override overrideWith(
    FutureOr<bool> Function(UnsubscribeFromSpaceRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: UnsubscribeFromSpaceProvider._internal(
        (ref) => create(ref as UnsubscribeFromSpaceRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        spaceSlug: spaceSlug,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<bool> createElement() {
    return _UnsubscribeFromSpaceProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is UnsubscribeFromSpaceProvider &&
        other.spaceSlug == spaceSlug;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, spaceSlug.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin UnsubscribeFromSpaceRef on AutoDisposeFutureProviderRef<bool> {
  /// The parameter `spaceSlug` of this provider.
  String get spaceSlug;
}

class _UnsubscribeFromSpaceProviderElement
    extends AutoDisposeFutureProviderElement<bool>
    with UnsubscribeFromSpaceRef {
  _UnsubscribeFromSpaceProviderElement(super.provider);

  @override
  String get spaceSlug => (origin as UnsubscribeFromSpaceProvider).spaceSlug;
}

String _$listSpacesByKeeperHash() =>
    r'f8156433ac38a512659635c1c84e29fd765ff02a';

/// See also [listSpacesByKeeper].
@ProviderFor(listSpacesByKeeper)
const listSpacesByKeeperProvider = ListSpacesByKeeperFamily();

/// See also [listSpacesByKeeper].
class ListSpacesByKeeperFamily
    extends Family<AsyncValue<List<SpaceDetailSchema>>> {
  /// See also [listSpacesByKeeper].
  const ListSpacesByKeeperFamily();

  /// See also [listSpacesByKeeper].
  ListSpacesByKeeperProvider call(String keeperSlug) {
    return ListSpacesByKeeperProvider(keeperSlug);
  }

  @override
  ListSpacesByKeeperProvider getProviderOverride(
    covariant ListSpacesByKeeperProvider provider,
  ) {
    return call(provider.keeperSlug);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'listSpacesByKeeperProvider';
}

/// See also [listSpacesByKeeper].
class ListSpacesByKeeperProvider
    extends AutoDisposeFutureProvider<List<SpaceDetailSchema>> {
  /// See also [listSpacesByKeeper].
  ListSpacesByKeeperProvider(String keeperSlug)
    : this._internal(
        (ref) => listSpacesByKeeper(ref as ListSpacesByKeeperRef, keeperSlug),
        from: listSpacesByKeeperProvider,
        name: r'listSpacesByKeeperProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$listSpacesByKeeperHash,
        dependencies: ListSpacesByKeeperFamily._dependencies,
        allTransitiveDependencies:
            ListSpacesByKeeperFamily._allTransitiveDependencies,
        keeperSlug: keeperSlug,
      );

  ListSpacesByKeeperProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.keeperSlug,
  }) : super.internal();

  final String keeperSlug;

  @override
  Override overrideWith(
    FutureOr<List<SpaceDetailSchema>> Function(ListSpacesByKeeperRef provider)
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ListSpacesByKeeperProvider._internal(
        (ref) => create(ref as ListSpacesByKeeperRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        keeperSlug: keeperSlug,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<SpaceDetailSchema>> createElement() {
    return _ListSpacesByKeeperProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ListSpacesByKeeperProvider &&
        other.keeperSlug == keeperSlug;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, keeperSlug.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ListSpacesByKeeperRef
    on AutoDisposeFutureProviderRef<List<SpaceDetailSchema>> {
  /// The parameter `keeperSlug` of this provider.
  String get keeperSlug;
}

class _ListSpacesByKeeperProviderElement
    extends AutoDisposeFutureProviderElement<List<SpaceDetailSchema>>
    with ListSpacesByKeeperRef {
  _ListSpacesByKeeperProviderElement(super.provider);

  @override
  String get keeperSlug => (origin as ListSpacesByKeeperProvider).keeperSlug;
}

String _$listSessionsHistoryHash() =>
    r'28a5e8c88cebc2f364efc555f8d94b9f8868167a';

/// See also [listSessionsHistory].
@ProviderFor(listSessionsHistory)
final listSessionsHistoryProvider =
    AutoDisposeFutureProvider<List<EventDetailSchema>>.internal(
      listSessionsHistory,
      name: r'listSessionsHistoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$listSessionsHistoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ListSessionsHistoryRef =
    AutoDisposeFutureProviderRef<List<EventDetailSchema>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
