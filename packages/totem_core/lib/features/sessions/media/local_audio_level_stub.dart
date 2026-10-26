import 'package:livekit_client/livekit_client.dart';

/// Browser-only; native builds use the LiveKit SDK visualizer instead.
Stream<double> localAudioLevel(AudioTrack track) =>
    throw UnsupportedError('localAudioLevel is only available on web');
