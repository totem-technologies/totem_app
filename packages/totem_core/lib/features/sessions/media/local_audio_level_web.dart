import 'dart:async';
import 'dart:js_interop';

import 'package:dart_webrtc/dart_webrtc.dart' show MediaStreamTrackWeb;

import 'package:livekit_client/livekit_client.dart';
import 'package:totem_core/features/sessions/media/local_audio_level.dart';
import 'package:totem_core/features/sessions/media/speech_level.dart';
import 'package:web/web.dart' as web;

/// Every analyser shares one context; browsers limit how many can run.
web.AudioContext? _audioContext;

/// Loudness for an [AudioTrack], read from the browser audio graph.
///
/// Uses one RMS measurement for the complete time-domain window, normalized
/// against the track's recent peak. The caller shapes this single loudness
/// value into its bars, avoiding arbitrary time slices and allocations.
Stream<double> localAudioLevel(AudioTrack track) {
  Timer? timer;
  web.MediaStreamAudioSourceNode? source;
  web.AnalyserNode? analyser;
  late final StreamController<double> controller;
  controller = StreamController<double>(
    onListen: () {
      final context = _audioContext ??= web.AudioContext();
      if (context.state == 'suspended') {
        // Safari refuses to resume outside a user gesture. The bars then read
        // silence until a later mount resumes the context.
        unawaited(context.resume().toDart.then((_) {}, onError: (_) {}));
      }
      final jsTrack = (track.mediaStreamTrack as MediaStreamTrackWeb).jsTrack;
      source = context.createMediaStreamSource(web.MediaStream([jsTrack].toJS));
      // About 21 ms at 48 kHz, close to the 20 ms packets whose levels the
      // browser reports for the remote bars.
      final node = context.createAnalyser()..fftSize = 1024;
      source!.connect(node);
      analyser = node;

      final buffer = JSFloat32Array.withLength(node.fftSize);
      // A view of the JS buffer, taken once; it sees each refill.
      final samples = buffer.toDart;
      final meter = SpeechLevelMeter();
      var shown = 0.0;
      timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        node.getFloatTimeDomainData(buffer);
        final next = heldSpeechLevel(shown, meter.level(rmsDb(samples)));
        if (next == shown) return;
        shown = next;
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
