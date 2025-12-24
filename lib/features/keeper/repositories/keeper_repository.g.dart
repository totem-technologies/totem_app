// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'keeper_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(keeperProfile)
const keeperProfileProvider = KeeperProfileFamily._();

final class KeeperProfileProvider
    extends
        $FunctionalProvider<
          AsyncValue<KeeperProfileSchema>,
          KeeperProfileSchema,
          FutureOr<KeeperProfileSchema>
        >
    with
        $FutureModifier<KeeperProfileSchema>,
        $FutureProvider<KeeperProfileSchema> {
  const KeeperProfileProvider._({
    required KeeperProfileFamily super.from,
    required String super.argument,
  }) : super(
         retry: _noRetry,
         name: r'keeperProfileProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$keeperProfileHash();

  @override
  String toString() {
    return r'keeperProfileProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<KeeperProfileSchema> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<KeeperProfileSchema> create(Ref ref) {
    final argument = this.argument as String;
    return keeperProfile(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is KeeperProfileProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$keeperProfileHash() => r'6f1ec6d314cd6846d7e86cd53968663096c5bc0a';

final class KeeperProfileFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<KeeperProfileSchema>, String> {
  const KeeperProfileFamily._()
    : super(
        retry: _noRetry,
        name: r'keeperProfileProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  KeeperProfileProvider call(String slug) =>
      KeeperProfileProvider._(argument: slug, from: this);

  @override
  String toString() => r'keeperProfileProvider';
}
