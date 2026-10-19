import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/features/sessions/media/local_media.dart';
import 'package:totem_core/features/sessions/media/web_audio_output_router.dart';

void main() {
  group('WebAudioOutputRouter', () {
    test('leaves a browser with only default output and no selection API controlled by the system', () async {
      final gateway = _FakeGateway(supportsSelection: false);
      final router = WebAudioOutputRouter(gateway: gateway);

      await router.start(() {});

      check(router.selectedDeviceId).isNull();
      check(gateway.startCount).equals(0);
      check(gateway.sinkIds).isEmpty();
    });

    test('selects a mobile or desktop output after validating its current availability', () async {
      final gateway = _FakeGateway(
        outputs: [fakeOutput('default'), fakeOutput('headphones')],
      );
      final router = WebAudioOutputRouter(gateway: gateway);
      var changes = 0;
      await router.start(() => changes++);

      await router.select(fakeOutput('headphones'));

      check(router.selectedDeviceId).equals('headphones');
      check(gateway.sinkIds).deepEquals(['headphones']);
      check(gateway.futureTrackSinkId).equals('headphones');
      check(changes).equals(1);
    });

    test(
      'falls back to the browser default when the selected output disappears',
      () async {
        final gateway = _FakeGateway(
          outputs: [fakeOutput('default'), fakeOutput('headphones')],
        );
        final router = WebAudioOutputRouter(gateway: gateway);
        await router.start(() {});
        await router.select(fakeOutput('headphones'));

        gateway
          ..outputs = [fakeOutput('default')]
          ..emitChange()
          ..emitChange();
        await Future<void>.microtask(() {});
        await router.pending;

        check(router.selectedDeviceId).isNull();
        check(gateway.sinkIds).deepEquals(['headphones', '']);
        check(gateway.futureTrackSinkId).equals('');
        check(gateway.audioOutputRequests).equals(2);
      },
    );

    test('keeps state on the browser default when setSinkId rejects', () async {
      final gateway = _FakeGateway(
        outputs: [fakeOutput('default'), fakeOutput('headphones')],
        setSinkIdError: StateError('permission denied'),
      );
      final router = WebAudioOutputRouter(gateway: gateway);
      await router.start(() {});

      await check(router.select(fakeOutput('headphones'))).throws<StateError>();

      check(router.selectedDeviceId).isNull();
      check(gateway.futureTrackSinkId).isNull();
    });

    test('refreshes browser outputs after choosing an output', () async {
      final headphones = fakeOutput('headphones');
      final gateway = _FakeGateway(
        supportsOutputChooser: true,
        outputs: [fakeOutput('default')],
        outputChooserResult: headphones,
      );
      final router = WebAudioOutputRouter(gateway: gateway);
      await router.start(() {});

      await router.requestAudioOutput();

      check(router.selectedDeviceId).equals('headphones');
      check(gateway.outputChooserRequests).equals(1);
      check(gateway.sinkIds).deepEquals(['headphones']);
      check(gateway.audioOutputRequests).equals(1);
    });

    test(
      'keeps the previous selection when the browser chooser is cancelled',
      () async {
        final gateway = _FakeGateway(
          supportsOutputChooser: true,
          outputs: [fakeOutput('default'), fakeOutput('headphones')],
        );
        final router = WebAudioOutputRouter(gateway: gateway);
        await router.start(() {});
        await router.select(fakeOutput('headphones'));
        gateway.outputChooserError = StateError('cancelled');

        await check(router.requestAudioOutput()).throws<StateError>();

        check(router.selectedDeviceId).equals('headphones');
        check(gateway.sinkIds).deepEquals(['headphones']);
      },
    );

    test(
      'serializes rapid device changes and releases browser listeners',
      () async {
        final gateway = _FakeGateway(
          outputs: [fakeOutput('default'), fakeOutput('headphones')],
        );
        final router = WebAudioOutputRouter(gateway: gateway);
        await router.start(() {});
        await router.select(fakeOutput('headphones'));

        gateway
          ..outputs = [fakeOutput('default')]
          ..emitChange()
          ..emitChange()
          ..emitChange();
        await Future<void>.microtask(() {});
        await router.pending;
        await router.stop();
        gateway.emitChange();
        await Future<void>.microtask(() {});

        check(gateway.sinkIds).deepEquals(['headphones', '']);
        check(gateway.stopCount).equals(1);
        check(gateway.audioOutputRequests).equals(2);
      },
    );

    test('restarts browser listeners after a queued teardown', () async {
      final gateway = _FakeGateway();
      final router = WebAudioOutputRouter(gateway: gateway);
      await router.start(() {});

      final stopping = router.stop();
      final restarting = router.start(() {});
      await Future.wait([stopping, restarting]);

      check(gateway.startCount).equals(2);
      check(gateway.stopCount).equals(1);
    });

    test('does not notify a stopped room after a late selection', () async {
      final gateway = _FakeGateway(
        outputs: [fakeOutput('default'), fakeOutput('headphones')],
      );
      final router = WebAudioOutputRouter(gateway: gateway);
      var changes = 0;
      await router.start(() => changes++);
      await router.stop();

      await router.select(fakeOutput('headphones'));

      check(changes).equals(0);
    });
  });
}

MediaDeviceInfo fakeOutput(String id) =>
    MediaDeviceInfo(id: id, label: id, kind: MediaDeviceKind.audioOutput);

class _FakeGateway implements WebAudioOutputGateway {
  new({
    this.supportsSelection = true,
    this.supportsOutputChooser = false,
    this.outputs = const [],
    this.setSinkIdError,
    this.outputChooserResult,
  });

  @override
  final bool supportsSelection;
  @override
  final bool supportsOutputChooser;
  List<MediaDeviceInfo> outputs;
  Error? setSinkIdError;
  MediaDeviceInfo? outputChooserResult;
  Error? outputChooserError;
  final _changes = StreamController<void>.broadcast(sync: true);
  final sinkIds = <String>[];
  int startCount = 0;
  int stopCount = 0;
  int audioOutputRequests = 0;
  int outputChooserRequests = 0;
  String? futureTrackSinkId;
  bool _started = false;

  void emitChange() => _changes.add(null);

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<List<MediaDeviceInfo>> audioOutputs() async {
    audioOutputRequests++;
    return outputs;
  }

  @override
  Future<MediaDeviceInfo> requestAudioOutput() async {
    outputChooserRequests++;
    final error = outputChooserError;
    if (error != null) throw error;
    final selected = outputChooserResult;
    if (selected == null) throw StateError('No output was selected.');
    if (!outputs.any((device) => device.id == selected.id)) {
      outputs = [...outputs, selected];
    }
    return selected;
  }

  @override
  Future<void> setSinkId(String deviceId) async {
    final error = setSinkIdError;
    if (error != null) throw error;
    sinkIds.add(deviceId);
    futureTrackSinkId = deviceId;
  }

  @override
  Future<void> start() async {
    if (_started) return;
    _started = true;
    startCount++;
  }

  @override
  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    stopCount++;
  }
}
