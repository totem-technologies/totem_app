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

String _$listSpacesHash() => r'52839e638c666de89cea3ceb580963c21158e9a4';

@ProviderFor(event)
final eventProvider = EventFamily._();

final class EventProvider
    extends
        $FunctionalProvider<
          AsyncValue<SessionDetailSchema>,
          SessionDetailSchema,
          FutureOr<SessionDetailSchema>
        >
    with
        $FutureModifier<SessionDetailSchema>,
        $FutureProvider<SessionDetailSchema> {
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
  $FutureProviderElement<SessionDetailSchema> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SessionDetailSchema> create(Ref ref) {
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

String _$eventHash() => r'0ea277c03d82ba2345a1eda0083aed2c986c0361';

final class EventFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<SessionDetailSchema>, String> {
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

String _$spaceHash() => r'394b182b744ce4d7965958be4dcabea9a802af82';

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
    r'b255592a1c17a3ae339f0c798caf67e690f736fd';

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

String _$subscribeToSpaceHash() => r'217bb3e64c2ea5de2df8015e354a5a41779459a1';

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
    r'd76f0421640f7cc09c6e995a469894c0a79df94e';

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
    r'97c825d79107257f896da14d0270b4e32a55b310';

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
          AsyncValue<List<SessionDetailSchema>>,
          List<SessionDetailSchema>,
          FutureOr<List<SessionDetailSchema>>
        >
    with
        $FutureModifier<List<SessionDetailSchema>>,
        $FutureProvider<List<SessionDetailSchema>> {
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
  $FutureProviderElement<List<SessionDetailSchema>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<SessionDetailSchema>> create(Ref ref) {
    return listSessionsHistory(ref);
  }
}

String _$listSessionsHistoryHash() =>
    r'd7e32c110bf14f63f1ebbe145db8b4517cd40d1f';

@ProviderFor(getRecommendedSessions)
final getRecommendedSessionsProvider = GetRecommendedSessionsFamily._();

final class GetRecommendedSessionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<SessionDetailSchema>>,
          List<SessionDetailSchema>,
          FutureOr<List<SessionDetailSchema>>
        >
    with
        $FutureModifier<List<SessionDetailSchema>>,
        $FutureProvider<List<SessionDetailSchema>> {
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
  $FutureProviderElement<List<SessionDetailSchema>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<SessionDetailSchema>> create(Ref ref) {
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
    r'715f75edb2e06edb5b7cea7016662b1d33365ae7';

final class GetRecommendedSessionsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<SessionDetailSchema>>,
          String?
        > {
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
