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

String _$listSpacesHash() => r'04640fc59fcd0f514dc454e14441d0c2d24b6906';

@ProviderFor(session)
final sessionProvider = SessionFamily._();

final class SessionProvider
    extends
        $FunctionalProvider<
          AsyncValue<SessionDetailSchema>,
          SessionDetailSchema,
          FutureOr<SessionDetailSchema>
        >
    with
        $FutureModifier<SessionDetailSchema>,
        $FutureProvider<SessionDetailSchema> {
  SessionProvider._({
    required SessionFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'sessionProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$sessionHash();

  @override
  String toString() {
    return r'sessionProvider'
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
    return session(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SessionProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$sessionHash() => r'25b3e427ca9703490eb7d3511af9ac7d0044b346';

final class SessionFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<SessionDetailSchema>, String> {
  SessionFamily._()
    : super(
        retry: null,
        name: r'sessionProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SessionProvider call(String sessionSlug) =>
      SessionProvider._(argument: sessionSlug, from: this);

  @override
  String toString() => r'sessionProvider';
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

String _$spaceHash() => r'ccaebcce5b8ab82c6ff9505b422f17bdb7ef0dd3';

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
    r'fb3688c7eb419bc4142ed03b31fb4cc0e4f74fba';

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

String _$subscribeToSpaceHash() => r'ecf0b8a817fda6f5b376dcece6b9675bf0ce4a10';

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
    r'0a36eeab5f3fabce3447068d758b22450a70c624';

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
    r'1c487eb346577b71acdde85ac7156c252d6a1026';

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
    r'8811a6e37f71c7d0ce9685e88c33cca191a09bad';

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
    required Set<SpaceCategories>? super.argument,
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
    final argument = this.argument as Set<SpaceCategories>?;
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
    r'a87a738df5ab6a6c9d075c4d1d74fbef7d35d032';

final class GetRecommendedSessionsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<SessionDetailSchema>>,
          Set<SpaceCategories>?
        > {
  GetRecommendedSessionsFamily._()
    : super(
        retry: null,
        name: r'getRecommendedSessionsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  GetRecommendedSessionsProvider call([Set<SpaceCategories>? topics]) =>
      GetRecommendedSessionsProvider._(argument: topics, from: this);

  @override
  String toString() => r'getRecommendedSessionsProvider';
}

@ProviderFor(spacesSummary)
final spacesSummaryProvider = SpacesSummaryProvider._();

final class SpacesSummaryProvider
    extends
        $FunctionalProvider<
          AsyncValue<SummarySpacesSchema>,
          SummarySpacesSchema,
          FutureOr<SummarySpacesSchema>
        >
    with
        $FutureModifier<SummarySpacesSchema>,
        $FutureProvider<SummarySpacesSchema> {
  SpacesSummaryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'spacesSummaryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$spacesSummaryHash();

  @$internal
  @override
  $FutureProviderElement<SummarySpacesSchema> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SummarySpacesSchema> create(Ref ref) {
    return spacesSummary(ref);
  }
}

String _$spacesSummaryHash() => r'a7405178005b5bea4f7fd4fe784810203d501655';

@ProviderFor(rsvpConfirm)
final rsvpConfirmProvider = RsvpConfirmFamily._();

final class RsvpConfirmProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  RsvpConfirmProvider._({
    required RsvpConfirmFamily super.from,
    required String super.argument,
  }) : super(
         retry: _noRetry,
         name: r'rsvpConfirmProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$rsvpConfirmHash();

  @override
  String toString() {
    return r'rsvpConfirmProvider'
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
    return rsvpConfirm(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is RsvpConfirmProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$rsvpConfirmHash() => r'2f925b0b3ee833a4cbcf010e508d62ed626cf267';

final class RsvpConfirmFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<bool>, String> {
  RsvpConfirmFamily._()
    : super(
        retry: _noRetry,
        name: r'rsvpConfirmProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  RsvpConfirmProvider call(String sessionSlug) =>
      RsvpConfirmProvider._(argument: sessionSlug, from: this);

  @override
  String toString() => r'rsvpConfirmProvider';
}

@ProviderFor(rsvpCancel)
final rsvpCancelProvider = RsvpCancelFamily._();

final class RsvpCancelProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  RsvpCancelProvider._({
    required RsvpCancelFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'rsvpCancelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$rsvpCancelHash();

  @override
  String toString() {
    return r'rsvpCancelProvider'
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
    return rsvpCancel(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is RsvpCancelProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$rsvpCancelHash() => r'660625f95950ee9787f003518f344c3b29d2c5cd';

final class RsvpCancelFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<bool>, String> {
  RsvpCancelFamily._()
    : super(
        retry: null,
        name: r'rsvpCancelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  RsvpCancelProvider call(String sessionSlug) =>
      RsvpCancelProvider._(argument: sessionSlug, from: this);

  @override
  String toString() => r'rsvpCancelProvider';
}

@ProviderFor(rsvpForceConfirm)
final rsvpForceConfirmProvider = RsvpForceConfirmFamily._();

final class RsvpForceConfirmProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  RsvpForceConfirmProvider._({
    required RsvpForceConfirmFamily super.from,
    required (String, List<String>) super.argument,
  }) : super(
         retry: null,
         name: r'rsvpForceConfirmProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$rsvpForceConfirmHash();

  @override
  String toString() {
    return r'rsvpForceConfirmProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    final argument = this.argument as (String, List<String>);
    return rsvpForceConfirm(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is RsvpForceConfirmProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$rsvpForceConfirmHash() => r'01796e9ec4ce56e74a9d71ae076be2ecefe7dd47';

final class RsvpForceConfirmFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<bool>, (String, List<String>)> {
  RsvpForceConfirmFamily._()
    : super(
        retry: null,
        name: r'rsvpForceConfirmProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  RsvpForceConfirmProvider call(
    String sessionSlug,
    List<String> conflictingSessionSlugs,
  ) => RsvpForceConfirmProvider._(
    argument: (sessionSlug, conflictingSessionSlugs),
    from: this,
  );

  @override
  String toString() => r'rsvpForceConfirmProvider';
}
