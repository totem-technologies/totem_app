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

String _$spacesSummaryHash() => r'6cbc4129b1b109847969ac7e9720e8538a6f597e';
