import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_core/features/sessions/media/livekit_local_media.dart';
import 'package:totem_core/features/sessions/media/local_media.dart';

part 'media_devices_provider.g.dart';

@Riverpod(keepAlive: true)
MediaDeviceCatalog mediaDeviceCatalog(Ref ref) => const LiveKitDeviceCatalog();

/// The current capture and playback devices, updated as devices are added or
/// removed.
@riverpod
Stream<List<MediaDeviceInfo>> mediaDevices(Ref ref) async* {
  final catalog = ref.watch(mediaDeviceCatalogProvider);
  final changes = catalog.changes;
  yield await catalog.devices();
  yield* changes;
}

@riverpod
List<MediaDeviceInfo> cameraDevices(Ref ref) {
  final devices = ref.watch(mediaDevicesProvider).value ?? const [];
  return [
    for (final device in devices)
      if (device.kind == MediaDeviceKind.videoInput) device,
  ];
}
