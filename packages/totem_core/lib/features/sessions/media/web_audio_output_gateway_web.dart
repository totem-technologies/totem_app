import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:totem_core/features/sessions/media/local_media.dart';
import 'package:totem_core/features/sessions/media/web_audio_output_router.dart';
import 'package:totem_core/shared/logger.dart';
import 'package:web/web.dart' as web;

WebAudioOutputGateway createWebAudioOutputGatewayImplementation() =>
    _BrowserWebAudioOutputGateway();

class _BrowserWebAudioOutputGateway implements WebAudioOutputGateway {
  final _changes = StreamController<void>.broadcast(sync: true);
  late final JSFunction _browserChangeListener = ((web.Event _) => _changes.add(
    null,
  )).toJS;
  late final JSFunction _visibilityChangeListener = ((web.Event _) {
    if (web.document.visibilityState == 'visible') _changes.add(null);
  }).toJS;
  web.MutationObserver? _observer;
  String? _sinkId;
  bool _started = false;

  bool get _hasMediaDevices =>
      web.window.navigator.hasProperty('mediaDevices'.toJS).toDart;

  @override
  bool get supportsSelection =>
      _hasMediaDevices &&
      web.HTMLAudioElement().hasProperty('setSinkId'.toJS).toDart;

  @override
  bool get supportsOutputChooser =>
      supportsSelection &&
      web.window.navigator.mediaDevices
          .hasProperty('selectAudioOutput'.toJS)
          .toDart;

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<void> start() async {
    if (_started || !supportsSelection) return;
    _started = true;
    final _ = web.window.navigator.mediaDevices
      ..addEventListener('devicechange', _browserChangeListener);
    web.window.addEventListener('focus', _browserChangeListener);
    web.document.addEventListener(
      'visibilitychange',
      _visibilityChangeListener,
    );
    _observer =
        web.MutationObserver(
          ((JSArray<web.MutationRecord> _, web.MutationObserver _) {
            unawaited(_applyToNewAudioElements());
          }).toJS,
        )..observe(
          web.document,
          web.MutationObserverInit(childList: true, subtree: true),
        );
  }

  @override
  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    final _ = web.window.navigator.mediaDevices
      ..removeEventListener('devicechange', _browserChangeListener);
    web.window.removeEventListener('focus', _browserChangeListener);
    web.document.removeEventListener(
      'visibilitychange',
      _visibilityChangeListener,
    );
    _observer?.disconnect();
    _observer = null;
    _sinkId = null;
  }

  @override
  Future<List<MediaDeviceInfo>> audioOutputs() async {
    final devices =
        (await web.window.navigator.mediaDevices.enumerateDevices().toDart)
            .toDart;
    return [
      for (final device in devices)
        if (device.kind == 'audiooutput')
          MediaDeviceInfo(
            id: device.deviceId,
            label: device.label,
            kind: MediaDeviceKind.audioOutput,
            groupId: device.groupId,
          ),
    ];
  }

  @override
  Future<MediaDeviceInfo> requestAudioOutput() async {
    if (!supportsOutputChooser) {
      throw UnsupportedError('Browser audio-output selection is unavailable.');
    }
    final selected = await web.window.navigator.mediaDevices
        .callMethod<JSPromise<web.MediaDeviceInfo>>('selectAudioOutput'.toJS)
        .toDart;
    return MediaDeviceInfo(
      id: selected.deviceId,
      label: selected.label,
      kind: MediaDeviceKind.audioOutput,
      groupId: selected.groupId,
    );
  }

  @override
  Future<void> setSinkId(String deviceId) async {
    if (!supportsSelection) {
      throw UnsupportedError('Browser audio-output selection is unavailable.');
    }
    await _applyToExistingAudioElements(deviceId);
    _sinkId = deviceId;
  }

  Future<void> _applyToNewAudioElements() async {
    final sinkId = _sinkId;
    if (!_started || sinkId == null) return;
    try {
      await _applyToExistingAudioElements(sinkId);
    } catch (error, stackTrace) {
      logger.w(
        'Failed to apply the selected browser audio output to a new track.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _applyToExistingAudioElements(String deviceId) async {
    final elements = web.document.querySelectorAll(
      '#livekit_audio_container audio',
    );
    for (var index = 0; index < elements.length; index++) {
      final element = elements.item(index);
      if (element == null || !element.instanceOfString('HTMLAudioElement')) {
        continue;
      }
      final audio = element as web.HTMLAudioElement;
      final promise = audio.callMethod<JSPromise<JSAny?>>(
        'setSinkId'.toJS,
        deviceId.toJS,
      );
      await promise.toDart;
    }
  }
}
