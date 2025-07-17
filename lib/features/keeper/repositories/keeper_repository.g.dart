// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'keeper_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

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
         retry: null,
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

String _$keeperProfileHash() => r'fedc805446263131ac613a3f65e4469570c7c40b';

final class KeeperProfileFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<KeeperProfileSchema>, String> {
  const KeeperProfileFamily._()
    : super(
        retry: null,
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

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
