import 'dart:async';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' hide ConnectionState;
import 'package:livekit_client/src/core/engine.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalParticipant extends Mock implements LocalParticipant {
  MockLocalParticipant([this.id = 'local-participant']);
  final String id;

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
  List<RemoteTrackPublication<RemoteVideoTrack>> get videoTrackPublications => [];

  @override
  List<RemoteTrackPublication<RemoteTrack>> getTrackPublications() => [];
}

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

class MockRemoteTrackPublication extends Mock implements RemoteTrackPublication<RemoteVideoTrack> {}

class MockRemoteVideoTrack extends Mock implements RemoteVideoTrack {}

class MockLocalVideoTrack extends Mock implements LocalVideoTrack {}

class MockTrackEventsListener extends Mock implements EventsListener<TrackEvent> {
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
