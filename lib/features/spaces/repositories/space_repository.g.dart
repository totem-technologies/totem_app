// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'space_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$listSpacesHash() => r'f72a41893135da9560c364fb136cd185894a4458';

/// See also [listSpaces].
@ProviderFor(listSpaces)
final listSpacesProvider =
    AutoDisposeFutureProvider<List<SpaceDetailSchema>>.internal(
      listSpaces,
      name: r'listSpacesProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$listSpacesHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ListSpacesRef = AutoDisposeFutureProviderRef<List<SpaceDetailSchema>>;
String _$eventHash() => r'b6fa9dde1ac9bcda3dea9b04e71a49a78f48e804';

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
  EventProvider call(String eventId) {
    return EventProvider(eventId);
  }

  @override
  EventProvider getProviderOverride(covariant EventProvider provider) {
    return call(provider.eventId);
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
  EventProvider(String eventId)
    : this._internal(
        (ref) => event(ref as EventRef, eventId),
        from: eventProvider,
        name: r'eventProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product') ? null : _$eventHash,
        dependencies: EventFamily._dependencies,
        allTransitiveDependencies: EventFamily._allTransitiveDependencies,
        eventId: eventId,
      );

  EventProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.eventId,
  }) : super.internal();

  final String eventId;

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
        eventId: eventId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<EventDetailSchema> createElement() {
    return _EventProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is EventProvider && other.eventId == eventId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, eventId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin EventRef on AutoDisposeFutureProviderRef<EventDetailSchema> {
  /// The parameter `eventId` of this provider.
  String get eventId;
}

class _EventProviderElement
    extends AutoDisposeFutureProviderElement<EventDetailSchema>
    with EventRef {
  _EventProviderElement(super.provider);

  @override
  String get eventId => (origin as EventProvider).eventId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
