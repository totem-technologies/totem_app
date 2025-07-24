// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connectivity_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$connectivityHash() => r'6d67af0ea4110f6ee0246dd332f90f8901380eda';

/// See also [connectivity].
@ProviderFor(connectivity)
final connectivityProvider = AutoDisposeProvider<Connectivity>.internal(
  connectivity,
  name: r'connectivityProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$connectivityHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ConnectivityRef = AutoDisposeProviderRef<Connectivity>;
String _$connectivityStreamHash() =>
    r'67159f6e1fedd7ed3da5924800bdf232db68da4c';

/// See also [connectivityStream].
@ProviderFor(connectivityStream)
final connectivityStreamProvider =
    AutoDisposeStreamProvider<List<ConnectivityResult>>.internal(
      connectivityStream,
      name: r'connectivityStreamProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$connectivityStreamHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ConnectivityStreamRef =
    AutoDisposeStreamProviderRef<List<ConnectivityResult>>;
String _$isOfflineHash() => r'226ea739d3f33712af77c459ed952164200c7f64';

/// See also [isOffline].
@ProviderFor(isOffline)
final isOfflineProvider = AutoDisposeFutureProvider<bool>.internal(
  isOffline,
  name: r'isOfflineProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$isOfflineHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef IsOfflineRef = AutoDisposeFutureProviderRef<bool>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
