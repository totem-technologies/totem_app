// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_screen_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

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

String _$spacesSummaryHash() => r'ad4e2a97bf985eb313eddbe24ae32dedbe8a4844';

@ProviderFor(rsvpConfirm)
final rsvpConfirmProvider = RsvpConfirmFamily._();

final class RsvpConfirmProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  RsvpConfirmProvider._({
    required RsvpConfirmFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
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

String _$rsvpConfirmHash() => r'd626308d00219ad86cc1834fcfb48475cd18f62a';

final class RsvpConfirmFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<bool>, String> {
  RsvpConfirmFamily._()
    : super(
        retry: null,
        name: r'rsvpConfirmProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  RsvpConfirmProvider call(String eventSlug) =>
      RsvpConfirmProvider._(argument: eventSlug, from: this);

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

String _$rsvpCancelHash() => r'917653b9c255846bdd3091588948a56230a82ee6';

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

  RsvpCancelProvider call(String eventSlug) =>
      RsvpCancelProvider._(argument: eventSlug, from: this);

  @override
  String toString() => r'rsvpCancelProvider';
}
