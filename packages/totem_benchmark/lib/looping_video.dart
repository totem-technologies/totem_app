import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'benchmark_config.dart';

/// One decoder and HTML platform view per participant; no camera or microphone.
class LoopingVideo extends StatefulWidget {
  const LoopingVideo({
    required this.mode,
    required this.participant,
    this.rounded = false,
    super.key,
  });

  final VideoMode mode;
  final int participant;
  final bool rounded;

  @override
  State<LoopingVideo> createState() => _LoopingVideoState();
}

class _LoopingVideoState extends State<LoopingVideo> {
  web.HTMLVideoElement? _video;

  void _configure() {
    final video = _video;
    if (video == null) return;
    video.style.borderRadius = widget.rounded ? '20px' : '0';
    video.autoplay = widget.mode == VideoMode.playing;
    if (widget.mode == VideoMode.playing) {
      // Autoplay occurs after the platform view is attached. Resuming an
      // already-attached view also needs play(). Playback errors remain visible
      // to the runner through the element's paused/error properties.
      if (video.isConnected) video.play();
    } else {
      video.pause();
    }
  }

  @override
  void didUpdateWidget(LoopingVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode || oldWidget.rounded != widget.rounded) {
      _configure();
    }
  }

  @override
  void dispose() {
    final video = _video;
    _video = null;
    video?.pause();
    video?.removeAttribute('src');
    video?.load();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView.fromTagName(
    tagName: 'video',
    onElementCreated: (element) {
      final video = element as web.HTMLVideoElement;
      _video = video;
      video
        ..setAttribute('data-participant', '${widget.participant}')
        ..src = 'loop.mp4'
        ..loop = true
        ..muted = true
        ..playsInline = true
        ..preload = 'auto';
      video.style
        ..width = '100%'
        ..height = '100%'
        ..objectFit = 'cover'
        ..pointerEvents = 'none';
      _configure();
    },
  );
}
