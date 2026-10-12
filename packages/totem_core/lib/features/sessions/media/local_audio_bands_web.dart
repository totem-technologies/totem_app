import 'dart:async';
import 'dart:js_interop';

import 'package:dart_webrtc/dart_webrtc.dart' show MediaStreamTrackWeb;
import 'package:livekit_client/livekit_client.dart';
import 'package:totem_core/features/sessions/media/local_audio_bands.dart';
import 'package:web/web.dart' as web;

/// Every analyser shares one context; browsers limit how many can run.
web.AudioContext? _audioContext;

/// Speech levels of a local microphone [track], for live feedback without
/// network delay. Reads the browser's analyser ten times a second into one
/// reused buffer, and emits only when the levels visibly change.
Stream<List<double>> localAudioBands(
  AudioTrack track, {
  required int bandCount,
}) {
  Timer? timer;
  web.MediaStreamAudioSourceNode? source;
  web.AnalyserNode? analyser;
  late final StreamController<List<double>> controller;
  controller = StreamController<List<double>>(
    onListen: () {
      final context = _audioContext ??= web.AudioContext();
      if (context.state == 'suspended') unawaited(context.resume().toDart);
      final jsTrack = (track.mediaStreamTrack as MediaStreamTrackWeb).jsTrack;
      source = context.createMediaStreamSource(
        web.MediaStream([jsTrack].toJS),
      );
      final node = context.createAnalyser()
        ..fftSize = 256
        ..smoothingTimeConstant = 0.6
        ..minDecibels = -100
        ..maxDecibels = -30;
      source!.connect(node);
      analyser = node;

      final buffer = JSUint8Array.withLength(node.frequencyBinCount);
      // A view of the JS buffer, taken once; it sees each refill.
      final spectrum = buffer.toDart;
      var last = const <double>[];
      timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        node.getByteFrequencyData(buffer);
        final next = speechBands(spectrum, bandCount);
        if (!speechBandsChanged(last, next)) return;
        last = next;
        controller.add(next);
      });
    },
    onCancel: () {
      timer?.cancel();
      source?.disconnect();
      analyser?.disconnect();
    },
  );
  return controller.stream;
}
