// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_devices_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(mediaDeviceCatalog)
final mediaDeviceCatalogProvider = MediaDeviceCatalogProvider._();

final class MediaDeviceCatalogProvider
    extends
        $FunctionalProvider<
          MediaDeviceCatalog,
          MediaDeviceCatalog,
          MediaDeviceCatalog
        >
    with $Provider<MediaDeviceCatalog> {
  MediaDeviceCatalogProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mediaDeviceCatalogProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mediaDeviceCatalogHash();

  @$internal
  @override
  $ProviderElement<MediaDeviceCatalog> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MediaDeviceCatalog create(Ref ref) {
    return mediaDeviceCatalog(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MediaDeviceCatalog value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MediaDeviceCatalog>(value),
    );
  }
}

String _$mediaDeviceCatalogHash() =>
    r'12e0ccc6b6dbbae025fd53be3fc2ecdb72a43e30';

/// The current capture and playback devices, updated as devices are added or
/// removed.

@ProviderFor(mediaDevices)
final mediaDevicesProvider = MediaDevicesProvider._();

/// The current capture and playback devices, updated as devices are added or
/// removed.

final class MediaDevicesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MediaDeviceInfo>>,
          List<MediaDeviceInfo>,
          Stream<List<MediaDeviceInfo>>
        >
    with
        $FutureModifier<List<MediaDeviceInfo>>,
        $StreamProvider<List<MediaDeviceInfo>> {
  /// The current capture and playback devices, updated as devices are added or
  /// removed.
  MediaDevicesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mediaDevicesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mediaDevicesHash();

  @$internal
  @override
  $StreamProviderElement<List<MediaDeviceInfo>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<MediaDeviceInfo>> create(Ref ref) {
    return mediaDevices(ref);
  }
}

String _$mediaDevicesHash() => r'7644d7078cb3edf3bc38934a96e52bbabd85c437';

@ProviderFor(cameraDevices)
final cameraDevicesProvider = CameraDevicesProvider._();

final class CameraDevicesProvider
    extends
        $FunctionalProvider<
          List<MediaDeviceInfo>,
          List<MediaDeviceInfo>,
          List<MediaDeviceInfo>
        >
    with $Provider<List<MediaDeviceInfo>> {
  CameraDevicesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cameraDevicesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cameraDevicesHash();

  @$internal
  @override
  $ProviderElement<List<MediaDeviceInfo>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  List<MediaDeviceInfo> create(Ref ref) {
    return cameraDevices(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<MediaDeviceInfo> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<MediaDeviceInfo>>(value),
    );
  }
}

String _$cameraDevicesHash() => r'ba7cb7af66458cb640c3e81a9af54197f173eb45';
