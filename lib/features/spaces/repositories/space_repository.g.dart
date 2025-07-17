// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'space_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

@ProviderFor(listSpaces)
const listSpacesProvider = ListSpacesProvider._();

final class ListSpacesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<SpaceDetailSchema>>,
          List<SpaceDetailSchema>,
          FutureOr<List<SpaceDetailSchema>>
        >
    with
        $FutureModifier<List<SpaceDetailSchema>>,
        $FutureProvider<List<SpaceDetailSchema>> {
  const ListSpacesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'listSpacesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$listSpacesHash();

  @$internal
  @override
  $FutureProviderElement<List<SpaceDetailSchema>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<SpaceDetailSchema>> create(Ref ref) {
    return listSpaces(ref);
  }
}

String _$listSpacesHash() => r'5e4af02f508d872c95e913011e610e8a394b548d';

@ProviderFor(event)
const eventProvider = EventFamily._();

final class EventProvider
    extends
        $FunctionalProvider<
          AsyncValue<EventDetailSchema>,
          EventDetailSchema,
          FutureOr<EventDetailSchema>
        >
    with
        $FutureModifier<EventDetailSchema>,
        $FutureProvider<EventDetailSchema> {
  const EventProvider._({
    required EventFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'eventProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$eventHash();

  @override
  String toString() {
    return r'eventProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<EventDetailSchema> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<EventDetailSchema> create(Ref ref) {
    final argument = this.argument as String;
    return event(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is EventProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$eventHash() => r'45c7d390bcdc6683294c1783234cff99bc4c79ab';

final class EventFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<EventDetailSchema>, String> {
  const EventFamily._()
    : super(
        retry: null,
        name: r'eventProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  EventProvider call(String eventSlug) =>
      EventProvider._(argument: eventSlug, from: this);

  @override
  String toString() => r'eventProvider';
}

@ProviderFor(listSubscribedSpaces)
const listSubscribedSpacesProvider = ListSubscribedSpacesProvider._();

final class ListSubscribedSpacesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<SpaceSchema>>,
          List<SpaceSchema>,
          FutureOr<List<SpaceSchema>>
        >
    with
        $FutureModifier<List<SpaceSchema>>,
        $FutureProvider<List<SpaceSchema>> {
  const ListSubscribedSpacesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'listSubscribedSpacesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$listSubscribedSpacesHash();

  @$internal
  @override
  $FutureProviderElement<List<SpaceSchema>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<SpaceSchema>> create(Ref ref) {
    return listSubscribedSpaces(ref);
  }
}

String _$listSubscribedSpacesHash() =>
    r'2b4b00c814f4fdd7b2ca99b6433d5fb8ff7aee5e';

@ProviderFor(subscribeToSpace)
const subscribeToSpaceProvider = SubscribeToSpaceFamily._();

final class SubscribeToSpaceProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  const SubscribeToSpaceProvider._({
    required SubscribeToSpaceFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'subscribeToSpaceProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$subscribeToSpaceHash();

  @override
  String toString() {
    return r'subscribeToSpaceProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    final argument = this.argument as String;
    return subscribeToSpace(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SubscribeToSpaceProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$subscribeToSpaceHash() => r'1bf0ba8b30966e2e5dce99fab5ddc30cf8bb19bf';

final class SubscribeToSpaceFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<bool>, String> {
  const SubscribeToSpaceFamily._()
    : super(
        retry: null,
        name: r'subscribeToSpaceProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SubscribeToSpaceProvider call(String spaceSlug) =>
      SubscribeToSpaceProvider._(argument: spaceSlug, from: this);

  @override
  String toString() => r'subscribeToSpaceProvider';
}

@ProviderFor(unsubscribeFromSpace)
const unsubscribeFromSpaceProvider = UnsubscribeFromSpaceFamily._();

final class UnsubscribeFromSpaceProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  const UnsubscribeFromSpaceProvider._({
    required UnsubscribeFromSpaceFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'unsubscribeFromSpaceProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$unsubscribeFromSpaceHash();

  @override
  String toString() {
    return r'unsubscribeFromSpaceProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    final argument = this.argument as String;
    return unsubscribeFromSpace(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is UnsubscribeFromSpaceProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$unsubscribeFromSpaceHash() =>
    r'9964930d5f0e388324fa3d1f85402123883c836e';

final class UnsubscribeFromSpaceFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<bool>, String> {
  const UnsubscribeFromSpaceFamily._()
    : super(
        retry: null,
        name: r'unsubscribeFromSpaceProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  UnsubscribeFromSpaceProvider call(String spaceSlug) =>
      UnsubscribeFromSpaceProvider._(argument: spaceSlug, from: this);

  @override
  String toString() => r'unsubscribeFromSpaceProvider';
}

@ProviderFor(listSpacesByKeeper)
const listSpacesByKeeperProvider = ListSpacesByKeeperFamily._();

final class ListSpacesByKeeperProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<SpaceDetailSchema>>,
          List<SpaceDetailSchema>,
          FutureOr<List<SpaceDetailSchema>>
        >
    with
        $FutureModifier<List<SpaceDetailSchema>>,
        $FutureProvider<List<SpaceDetailSchema>> {
  const ListSpacesByKeeperProvider._({
    required ListSpacesByKeeperFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'listSpacesByKeeperProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$listSpacesByKeeperHash();

  @override
  String toString() {
    return r'listSpacesByKeeperProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<SpaceDetailSchema>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<SpaceDetailSchema>> create(Ref ref) {
    final argument = this.argument as String;
    return listSpacesByKeeper(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ListSpacesByKeeperProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$listSpacesByKeeperHash() =>
    r'f8156433ac38a512659635c1c84e29fd765ff02a';

final class ListSpacesByKeeperFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<SpaceDetailSchema>>, String> {
  const ListSpacesByKeeperFamily._()
    : super(
        retry: null,
        name: r'listSpacesByKeeperProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ListSpacesByKeeperProvider call(String keeperSlug) =>
      ListSpacesByKeeperProvider._(argument: keeperSlug, from: this);

  @override
  String toString() => r'listSpacesByKeeperProvider';
}

@ProviderFor(listSessionsHistory)
const listSessionsHistoryProvider = ListSessionsHistoryProvider._();

final class ListSessionsHistoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<EventDetailSchema>>,
          List<EventDetailSchema>,
          FutureOr<List<EventDetailSchema>>
        >
    with
        $FutureModifier<List<EventDetailSchema>>,
        $FutureProvider<List<EventDetailSchema>> {
  const ListSessionsHistoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'listSessionsHistoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$listSessionsHistoryHash();

  @$internal
  @override
  $FutureProviderElement<List<EventDetailSchema>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<EventDetailSchema>> create(Ref ref) {
    return listSessionsHistory(ref);
  }
}

String _$listSessionsHistoryHash() =>
    r'28a5e8c88cebc2f364efc555f8d94b9f8868167a';

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
