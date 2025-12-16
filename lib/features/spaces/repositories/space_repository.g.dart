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
          AsyncValue<List<MobileSpaceDetailSchema>>,
          List<MobileSpaceDetailSchema>,
          FutureOr<List<MobileSpaceDetailSchema>>
        >
    with
        $FutureModifier<List<MobileSpaceDetailSchema>>,
        $FutureProvider<List<MobileSpaceDetailSchema>> {
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
  $FutureProviderElement<List<MobileSpaceDetailSchema>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<MobileSpaceDetailSchema>> create(Ref ref) {
    return listSpaces(ref);
  }
}

String _$listSpacesHash() => r'60d98d341561665b3c08711308e213e83245c886';

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

String _$eventHash() => r'615390d7fd612a7d263dc84760a4e27c01f1eba2';

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
          AsyncValue<MobileSpaceDetailSchema>,
          MobileSpaceDetailSchema,
          FutureOr<MobileSpaceDetailSchema>
        >
    with
        $FutureModifier<MobileSpaceDetailSchema>,
        $FutureProvider<MobileSpaceDetailSchema> {
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
  $FutureProviderElement<MobileSpaceDetailSchema> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<MobileSpaceDetailSchema> create(Ref ref) {
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

String _$spaceHash() => r'1d9fd0f3e7ee9e80f9dbe94d06e430369ecc195b';

final class SpaceFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<MobileSpaceDetailSchema>, String> {
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
    r'3c62c796fd9a8586582b40e4e9c4e99d37887143';

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

String _$subscribeToSpaceHash() => r'cfcfc238f3f86b237cd44ba56fb614cdf40f1f98';

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
    r'190b23674b824dccc43c68327e307bf3c4f18845';

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
          AsyncValue<List<MobileSpaceDetailSchema>>,
          List<MobileSpaceDetailSchema>,
          FutureOr<List<MobileSpaceDetailSchema>>
        >
    with
        $FutureModifier<List<MobileSpaceDetailSchema>>,
        $FutureProvider<List<MobileSpaceDetailSchema>> {
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
  $FutureProviderElement<List<MobileSpaceDetailSchema>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<MobileSpaceDetailSchema>> create(Ref ref) {
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
    r'ea460cb115a2e57632046f3a645eb5644acecd8f';

final class ListSpacesByKeeperFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<MobileSpaceDetailSchema>>,
          String
        > {
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
    r'db5edd6a2e1b7b120ce62925d0d8de583ab38799';

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
    r'981d0bfbb48b9101cec184b97c0a2c6777b82ad5';

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
