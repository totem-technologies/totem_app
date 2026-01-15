// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'space_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(listSpaces)
final listSpacesProvider = ListSpacesProvider._();

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
  ListSpacesProvider._()
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

String _$listSpacesHash() => r'408c472973ef34bfdc606357b93856c2afd0f570';

@ProviderFor(event)
final eventProvider = EventFamily._();

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
  EventProvider._({
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

String _$eventHash() => r'41915faecccdd05abac94bf2404494cc53ad320c';

final class EventFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<EventDetailSchema>, String> {
  EventFamily._()
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
final spaceProvider = SpaceFamily._();

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
  SpaceProvider._({
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

String _$spaceHash() => r'0a7c201b4bb48c32db6e02a58cf0c8c421ce241f';

final class SpaceFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<MobileSpaceDetailSchema>, String> {
  SpaceFamily._()
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
final listSubscribedSpacesProvider = ListSubscribedSpacesProvider._();

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
  ListSubscribedSpacesProvider._()
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
    r'3b69d91b62109c709802530db370f8056383d723';

@ProviderFor(subscribeToSpace)
final subscribeToSpaceProvider = SubscribeToSpaceFamily._();

final class SubscribeToSpaceProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  SubscribeToSpaceProvider._({
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

String _$subscribeToSpaceHash() => r'a4ad0210d97c06f9d1d30e59ea8e41fb444de736';

final class SubscribeToSpaceFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<bool>, String> {
  SubscribeToSpaceFamily._()
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
final unsubscribeFromSpaceProvider = UnsubscribeFromSpaceFamily._();

final class UnsubscribeFromSpaceProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  UnsubscribeFromSpaceProvider._({
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
    r'fd5cc65eb4a14fac326ffc7c4ffe440767c08ce8';

final class UnsubscribeFromSpaceFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<bool>, String> {
  UnsubscribeFromSpaceFamily._()
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
final listSpacesByKeeperProvider = ListSpacesByKeeperFamily._();

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
  ListSpacesByKeeperProvider._({
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
    r'3a942dcae948f55fa347486aa8452ce1fe15b4c1';

final class ListSpacesByKeeperFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<MobileSpaceDetailSchema>>,
          String
        > {
  ListSpacesByKeeperFamily._()
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
final listSessionsHistoryProvider = ListSessionsHistoryProvider._();

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
  ListSessionsHistoryProvider._()
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
    r'1e2adbdf2646b92ac43a3fcf0084f45dbd22bb23';

@ProviderFor(getRecommendedSessions)
final getRecommendedSessionsProvider = GetRecommendedSessionsFamily._();

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
  GetRecommendedSessionsProvider._({
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
    r'dc7a248558064985e6bcccb1e2cc336f08fe0c43';

final class GetRecommendedSessionsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<EventDetailSchema>>, String?> {
  GetRecommendedSessionsFamily._()
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
