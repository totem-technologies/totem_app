// ignore_for_file: prefer_final_fields

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;
import 'package:livekit_client/livekit_client.dart' hide ConnectionState;
import 'package:livekit_client/src/core/engine.dart';
import 'package:livekit_client/src/stats/stats.dart' show VideoReceiverStats;
import 'package:livekit_client/src/track/video_track_view_registration.dart';
import 'package:mocktail/mocktail.dart';

class MockMediaStream extends Mock implements webrtc.MediaStream {
  @override
  String get id => 'mock-stream-id';

  @override
  String get ownerTag => 'mock-owner-tag';
}

/// Stubs the flutter_webrtc platform channels so [VideoTrackRenderer] can
/// initialize inside widget tests without a real platform. Returns a teardown.
VoidCallback stubFlutterWebRtcChannels() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  var nextTextureId = 1;
  final textureChannels = <MethodChannel>[];

  const mainChannel = MethodChannel('FlutterWebRTC.Method');
  messenger.setMockMethodCallHandler(mainChannel, (call) async {
    switch (call.method) {
      case 'createVideoRenderer':
        final textureId = nextTextureId++;
        final textureChannel = MethodChannel(
          'FlutterWebRTC/Texture$textureId',
        );
        messenger.setMockMethodCallHandler(textureChannel, (_) async => null);
        textureChannels.add(textureChannel);
        return {'textureId': textureId};
      case 'getSources':
        return {'sources': <dynamic>[]};
      case 'videoRendererSetSrcObject':
      case 'videoRendererDispose':
        return null;
    }
    return null;
  });

  return () {
    messenger.setMockMethodCallHandler(mainChannel, null);
    for (final channel in textureChannels) {
      messenger.setMockMethodCallHandler(channel, null);
    }
  };
}

class MockLocalParticipant extends Mock implements LocalParticipant {
  MockLocalParticipant([
    this.id = 'local-participant',
    this.participantName = 'Local Participant',
  ]);
  final String id;
  final String participantName;

  @override
  String get name => participantName;

  @override
  String get identity => id;

  @override
  String get sid => id;

  @override
  List<LocalTrackPublication<LocalAudioTrack>> get audioTrackPublications => [];

  @override
  List<LocalTrackPublication<LocalVideoTrack>> get videoTrackPublications => [];

  @override
  List<LocalTrackPublication<LocalTrack>> getTrackPublications() => [];
}

class FakeRoom extends Fake implements Room {
  FakeRoom(this.participant);

  final MockLocalParticipant participant;

  @override
  LocalParticipant get localParticipant => participant;

  bool _speakerOn = false;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #engine) return FakeEngine();
    if (invocation.memberName == #roomOptions) return const RoomOptions();
    if (invocation.memberName == #speakerOn) return _speakerOn;
    if (invocation.memberName == #setSpeakerOn) {
      _speakerOn = invocation.positionalArguments[0] as bool;
      return Future<void>.value();
    }
    if (invocation.memberName == #selectedVideoInputDeviceId) return null;
    return super.noSuchMethod(invocation);
  }
}

class FakeEngine extends Fake implements Engine {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #roomOptions) return const RoomOptions();
    return super.noSuchMethod(invocation);
  }
}

class FakeCameraCaptureOptions extends Fake implements CameraCaptureOptions {}

class MockRemoteParticipant extends Mock implements RemoteParticipant {
  MockRemoteParticipant(this.id, this.name);

  final String id;
  @override
  final String name;

  @override
  String get identity => id;

  @override
  String get sid => id;

  @override
  bool get hasAudio => true;

  @override
  bool get isMuted => false;

  @override
  List<RemoteTrackPublication<RemoteVideoTrack>> get videoTrackPublications =>
      [];

  @override
  List<RemoteTrackPublication<RemoteTrack>> getTrackPublications() => [];
}

class MockRemoteAudioTrack extends Mock implements RemoteAudioTrack {
  MockRemoteAudioTrack({bool muted = false, bool isActive = true})
    : _muted = muted,
      _isActive = isActive {
    when(() => this.muted).thenAnswer((_) => _muted);
    when(() => this.isActive).thenAnswer((_) => _isActive);
    when(start).thenAnswer((_) async => true);
    when(stop).thenAnswer((_) async => true);
    when(dispose).thenAnswer((_) async => true);
  }

  bool _muted;
  bool _isActive;
  final CapturingTrackEventsListener trackListener =
      CapturingTrackEventsListener();

  // ignore: use_setters_to_change_properties
  void setMuted(bool value) {
    _muted = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #createListener) {
      return trackListener;
    }
    return super.noSuchMethod(invocation);
  }
}

class MockRemoteAudioTrackPublication extends Mock
    implements RemoteTrackPublication<RemoteAudioTrack> {}

class MockTrackMutedEvent extends Mock implements TrackMutedEvent {}

class MockTrackUnmutedEvent extends Mock implements TrackUnmutedEvent {}

class MockTrackEvent extends Mock implements TrackEvent {}

class MockMediaStreamTrack extends Mock implements webrtc.MediaStreamTrack {}

class MockParticipantEventsListener extends Mock
    implements EventsListener<ParticipantEvent> {
  @override
  CancelListenFunc on<E>(
    FutureOr<void> Function(E event) listener, {
    bool Function(E)? filter,
  }) {
    return () async {};
  }

  @override
  Future<bool> dispose() async {
    return true;
  }
}

class MockRemoteTrackPublication extends Mock
    implements RemoteTrackPublication<RemoteVideoTrack> {}

class MockLocalTrackPublication extends Mock
    implements LocalTrackPublication<LocalVideoTrack> {
  MockLocalTrackPublication({
    bool muted = false,
    bool isActive = true,
  }) {
    when(
      () => track,
    ).thenAnswer((_) => MockLocalVideoTrack(muted: muted, isActive: isActive));
  }
}

// Default stubs for the VideoTrack mixin methods the SDK calls during
// VideoTrackRenderer initState/dispose. Returning sane values here keeps
// individual tests from having to repeat these three lines.
dynamic _videoTrackDefaults(Invocation invocation) {
  switch (invocation.memberName) {
    case #registerVideoView:
      return 'mock-view-id';
    case #unregisterVideoView:
      return null;
    case #addViewRegistration:
      return VideoTrackViewRegistration();
    case #removeViewRegistration:
      return null;
    case #source:
      return TrackSource.camera;
    case #mediaStream:
      return MockMediaStream();
  }
  return null;
}

// Members that legitimately return null from the defaults above; without
// this allowlist they would fall through to mocktail's noSuchMethod and
// throw for being unstubbed.
const _videoTrackVoidMembers = {#unregisterVideoView, #removeViewRegistration};

class MockRemoteVideoTrack extends Mock implements RemoteVideoTrack {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    final defaulted = _videoTrackDefaults(invocation);
    if (defaulted != null ||
        _videoTrackVoidMembers.contains(invocation.memberName)) {
      return defaulted;
    }
    return super.noSuchMethod(invocation);
  }
}

class MockLocalVideoTrack extends Mock implements LocalVideoTrack {
  MockLocalVideoTrack({bool muted = false, bool isActive = true})
    : _muted = muted,
      _isActive = isActive {
    when(() => this.muted).thenAnswer((_) => _muted);
    when(() => this.isActive).thenAnswer((_) => _isActive);
    when(start).thenAnswer((_) async => true);
    when(stop).thenAnswer((_) async => true);
    when(dispose).thenAnswer((_) async => true);
  }

  bool _muted;
  bool _isActive;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final defaulted = _videoTrackDefaults(invocation);
    if (defaulted != null ||
        _videoTrackVoidMembers.contains(invocation.memberName)) {
      return defaulted;
    }
    return super.noSuchMethod(invocation);
  }
}

class MockLocalAudioTrack extends Mock implements LocalAudioTrack {
  MockLocalAudioTrack({bool muted = false, bool isActive = true})
    : _muted = muted,
      _isActive = isActive {
    when(() => this.muted).thenAnswer((_) => _muted);
    when(() => this.isActive).thenAnswer((_) => _isActive);
    when(enable).thenAnswer((_) async => true);
    when(start).thenAnswer((_) async => true);
    when(stop).thenAnswer((_) async => true);
    when(dispose).thenAnswer((_) async => true);
    when(() => mute(stopOnMute: false)).thenAnswer((_) async {
      _muted = true;
      return true;
    });
    when(() => unmute(stopOnMute: false)).thenAnswer((_) async {
      _muted = false;
      return true;
    });
  }

  bool _muted;
  bool _isActive;
}

class MockTrackEventsListener extends Mock
    implements EventsListener<TrackEvent> {
  @override
  CancelListenFunc on<E>(
    FutureOr<void> Function(E event) listener, {
    bool Function(E)? filter,
  }) {
    return () async {};
  }

  @override
  CancelListenFunc listen(void Function(TrackEvent event) listener) {
    return () async {};
  }

  @override
  Future<bool> dispose() async {
    return true;
  }
}

class CapturingParticipantEventsListener extends MockParticipantEventsListener {
  void Function(TrackMutedEvent event)? onMuted;
  void Function(TrackUnmutedEvent event)? onUnmuted;

  @override
  CancelListenFunc on<E>(
    FutureOr<void> Function(E event) listener, {
    bool Function(E)? filter,
  }) {
    if (E == TrackMutedEvent) {
      onMuted = listener as void Function(TrackMutedEvent);
    } else if (E == TrackUnmutedEvent) {
      onUnmuted = listener as void Function(TrackUnmutedEvent);
    }
    return () async {};
  }

  void emitMuted(TrackMutedEvent event) => onMuted?.call(event);

  void emitUnmuted(TrackUnmutedEvent event) => onUnmuted?.call(event);
}

class CapturingTrackEventsListener extends MockTrackEventsListener {
  void Function(TrackEvent event)? capturedListener;

  @override
  CancelListenFunc listen(void Function(TrackEvent event) listener) {
    capturedListener = listener;
    return () async {};
  }

  void emit(TrackEvent event) => capturedListener?.call(event);
}

class MockVideoReceiverStats extends Mock implements VideoReceiverStats {}

class MockVideoReceiverStatsEvent extends Mock
    implements VideoReceiverStatsEvent {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #stats) return MockVideoReceiverStats();
    return super.noSuchMethod(invocation);
  }
}
