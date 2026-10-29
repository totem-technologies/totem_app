import 'dart:async';

import 'package:totem_core/features/sessions/media/local_media.dart';
import 'package:totem_core/features/sessions/media/web_audio_output_router.dart';

WebAudioOutputGateway createWebAudioOutputGatewayImplementation() =>
    const _UnsupportedWebAudioOutputGateway();

class _UnsupportedWebAudioOutputGateway implements WebAudioOutputGateway {
  const _UnsupportedWebAudioOutputGateway();

  @override
  bool get supportsSelection => false;

  @override
  bool get supportsOutputChooser => false;

  @override
  Stream<void> get changes => const Stream.empty();

  @override
  Future<List<MediaDeviceInfo>> audioOutputs() async => const [];

  @override
  Future<MediaDeviceInfo> requestAudioOutput() => Future.error(
    UnsupportedError('Browser audio-output selection is unavailable.'),
  );

  @override
  Future<void> setSinkId(String deviceId) => Future.error(
    UnsupportedError('Browser audio-output selection is unavailable.'),
  );

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}
}
