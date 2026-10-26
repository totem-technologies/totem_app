import 'package:livekit_client/livekit_client.dart';

/// Browser-only; native builds use the LiveKit SDK visualizer instead.
Stream<List<double>> localAudioLevels(
  AudioTrack track, {
  required int barCount,
}) => throw UnsupportedError('localAudioLevels is only available on web');
