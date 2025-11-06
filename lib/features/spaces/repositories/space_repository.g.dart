// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'space_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

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
        isAutoDispose: false,
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

String _$listSpacesHash() => r'c17a7ffbca65ff4ee39431b66791b74eed094662';

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

String _$eventHash() => r'60445a2aabe84e14ff7e17089355ef0be27a27b2';

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

@ProviderFor(space)
const spaceProvider = SpaceFamily._();

final class SpaceProvider
    extends
        $FunctionalProvider<
          AsyncValue<SpaceDetailSchema>,
          SpaceDetailSchema,
          FutureOr<SpaceDetailSchema>
        >
    with
        $FutureModifier<SpaceDetailSchema>,
        $FutureProvider<SpaceDetailSchema> {
  const SpaceProvider._({
    required SpaceFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'spaceProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$spaceHash();

  @override
  String toString() {
    return r'spaceProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<SpaceDetailSchema> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SpaceDetailSchema> create(Ref ref) {
    final argument = this.argument as String;
    return space(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SpaceProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$spaceHash() => r'76dea1bd725e131af36ec341588d5d89b1a8c5de';

final class SpaceFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<SpaceDetailSchema>, String> {
  const SpaceFamily._()
    : super(
        retry: null,
        name: r'spaceProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SpaceProvider call(String spaceSlug) =>
      SpaceProvider._(argument: spaceSlug, from: this);

  @override
  String toString() => r'spaceProvider';
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
    r'163a850d3d5db71189d86ea743671679be64bb2f';

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
    r'669b9babcb1f41a9d0e855b3e1592935fb14d10c';

@ProviderFor(getRecommendedSessions)
const getRecommendedSessionsProvider = GetRecommendedSessionsFamily._();

final class GetRecommendedSessionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<EventDetailSchema>>,
          List<EventDetailSchema>,
          FutureOr<List<EventDetailSchema>>
        >
    with
        $FutureModifier<List<EventDetailSchema>>,
        $FutureProvider<List<EventDetailSchema>> {
  const GetRecommendedSessionsProvider._({
    required GetRecommendedSessionsFamily super.from,
    required String? super.argument,
  }) : super(
         retry: null,
         name: r'getRecommendedSessionsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$getRecommendedSessionsHash();

  @override
  String toString() {
    return r'getRecommendedSessionsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<EventDetailSchema>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<EventDetailSchema>> create(Ref ref) {
    final argument = this.argument as String?;
    return getRecommendedSessions(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is GetRecommendedSessionsProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$getRecommendedSessionsHash() =>
    r'c575e9eb802efdbbdd9b4a1d5f8e4efc6ab2ea56';

final class GetRecommendedSessionsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<EventDetailSchema>>, String?> {
  const GetRecommendedSessionsFamily._()
    : super(
        retry: null,
        name: r'getRecommendedSessionsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  GetRecommendedSessionsProvider call([String? topicsKey]) =>
      GetRecommendedSessionsProvider._(argument: topicsKey, from: this);

  @override
  String toString() => r'getRecommendedSessionsProvider';
}
