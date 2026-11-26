// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'firebase_messaging_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(firebaseMessagingService)
final firebaseMessagingServiceProvider = FirebaseMessagingServiceProvider._();

final class FirebaseMessagingServiceProvider
    extends
        $FunctionalProvider<
          FirebaseMessagingService,
          FirebaseMessagingService,
          FirebaseMessagingService
        >
    with $Provider<FirebaseMessagingService> {
  FirebaseMessagingServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'firebaseMessagingServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$firebaseMessagingServiceHash();

  @$internal
  @override
  $ProviderElement<FirebaseMessagingService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  FirebaseMessagingService create(Ref ref) {
    return firebaseMessagingService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FirebaseMessagingService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FirebaseMessagingService>(value),
    );
  }
}

String _$firebaseMessagingServiceHash() =>
    r'd81a7cafbdb19673a4e332d8ce2c3d1c4e9a6928';
