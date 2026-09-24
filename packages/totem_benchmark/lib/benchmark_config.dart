enum VideoMode { playing, paused, hidden }

enum WaveformMode { animated, frozen, hidden }

enum TileClip { antiAlias, hardEdge, none, css }

/// URL configuration is deliberately bounded so a typo fails visibly.
class BenchmarkConfig {
  const BenchmarkConfig({
    this.participants = 6,
    this.video = VideoMode.playing,
    this.waveform = WaveformMode.animated,
    this.notice = true,
    this.clip = TileClip.antiAlias,
    this.overlays = true,
  });

  factory BenchmarkConfig.fromQuery(Map<String, String> query) {
    const keys = {
      'participants',
      'video',
      'waveform',
      'notice',
      'clip',
      'overlays',
    };
    if (query.keys.any((key) => !keys.contains(key))) {
      throw const FormatException('Unknown benchmark option');
    }
    final participants = int.parse(query['participants'] ?? '6');
    if (participants < 1 || participants > 12) {
      throw const FormatException('participants must be between 1 and 12');
    }
    final notice = query['notice'] ?? 'true';
    if (notice != 'true' && notice != 'false') {
      throw const FormatException('notice must be true or false');
    }
    final overlays = query['overlays'] ?? 'true';
    if (overlays != 'true' && overlays != 'false') {
      throw const FormatException('overlays must be true or false');
    }
    return BenchmarkConfig(
      participants: participants,
      video:
          VideoMode.values
              .where((value) => value.name == (query['video'] ?? 'playing'))
              .firstOrNull ??
          (throw const FormatException('Invalid video mode')),
      waveform:
          WaveformMode.values
              .where((value) => value.name == (query['waveform'] ?? 'animated'))
              .firstOrNull ??
          (throw const FormatException('Invalid waveform mode')),
      notice: notice == 'true',
      overlays: overlays == 'true',
      clip:
          TileClip.values
              .where((value) => value.name == (query['clip'] ?? 'antiAlias'))
              .firstOrNull ??
          (throw const FormatException('Invalid clip mode')),
    );
  }

  final int participants;
  final VideoMode video;
  final WaveformMode waveform;
  final bool notice;
  final TileClip clip;
  final bool overlays;

  Map<String, Object> toJson() => {
    'participants': participants,
    'video': video.name,
    'waveform': waveform.name,
    'notice': notice,
    'clip': clip.name,
    'overlays': overlays,
  };
}
