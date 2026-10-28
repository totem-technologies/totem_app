// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_permission_adapter.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(mediaPermissionAdapter)
final mediaPermissionAdapterProvider = MediaPermissionAdapterProvider._();

final class MediaPermissionAdapterProvider
    extends
        $FunctionalProvider<
          MediaPermissionAdapter,
          MediaPermissionAdapter,
          MediaPermissionAdapter
        >
    with $Provider<MediaPermissionAdapter> {
  MediaPermissionAdapterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mediaPermissionAdapterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mediaPermissionAdapterHash();

  @$internal
  @override
  $ProviderElement<MediaPermissionAdapter> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MediaPermissionAdapter create(Ref ref) {
    return mediaPermissionAdapter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MediaPermissionAdapter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MediaPermissionAdapter>(value),
    );
  }
}

String _$mediaPermissionAdapterHash() =>
    r'd4a3a33b00c9ea32718627bb355108945d173389';
