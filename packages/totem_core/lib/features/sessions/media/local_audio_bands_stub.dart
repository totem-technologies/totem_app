import 'package:livekit_client/livekit_client.dart';

/// Browser-only; native builds use the LiveKit SDK visualizer instead.
Stream<List<double>> localAudioBands(
  AudioTrack track, {
  required int bandCount,
}) => throw UnsupportedError('localAudioBands is only available on web');
