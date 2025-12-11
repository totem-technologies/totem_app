// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_screen_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(spacesSummary)
const spacesSummaryProvider = SpacesSummaryProvider._();

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
  const SpacesSummaryProvider._()
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

String _$spacesSummaryHash() => r'0182c977e4b2b65257c2203eb9cbd3747e119dfc';
