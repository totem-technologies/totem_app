// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'keeper_admission_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(keeperAdmissionRepository)
final keeperAdmissionRepositoryProvider = KeeperAdmissionRepositoryProvider._();

final class KeeperAdmissionRepositoryProvider
    extends
        $FunctionalProvider<
          KeeperAdmissionRepository,
          KeeperAdmissionRepository,
          KeeperAdmissionRepository
        >
    with $Provider<KeeperAdmissionRepository> {
  KeeperAdmissionRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'keeperAdmissionRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$keeperAdmissionRepositoryHash();

  @$internal
  @override
  $ProviderElement<KeeperAdmissionRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  KeeperAdmissionRepository create(Ref ref) {
    return keeperAdmissionRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(KeeperAdmissionRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<KeeperAdmissionRepository>(value),
    );
  }
}

String _$keeperAdmissionRepositoryHash() =>
    r'6be33a1cb9f101495da738249710d752a05dece1';
