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
  web.MutationObserver? _audioContainerObserver;
  web.MutationObserver? _audioElementsObserver;
  String? _sinkId;
  bool _isChangingSink = false;
  bool _started = false;

  late final bool _supportsSelection =
      web.window.navigator.hasProperty('mediaDevices'.toJS).toDart &&
      web.HTMLAudioElement().hasProperty('setSinkId'.toJS).toDart;
  late final bool _supportsOutputChooser =
      _supportsSelection &&
      web.window.navigator.mediaDevices
          .hasProperty('selectAudioOutput'.toJS)
          .toDart;

  @override
  bool get supportsSelection => _supportsSelection;

  @override
  bool get supportsOutputChooser => _supportsOutputChooser;

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
    _observeAudioElements();
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
    _audioContainerObserver?.disconnect();
    _audioContainerObserver = null;
    _audioElementsObserver?.disconnect();
    _audioElementsObserver = null;
    if (_sinkId case final sinkId? when sinkId.isNotEmpty) {
      try {
        await _applyToExistingAudioElements('', rollbackSinkId: sinkId);
      } catch (error, stackTrace) {
        logger.w(
          'Failed to restore browser-default audio output during cleanup.',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
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
    final previousSinkId = _sinkId ?? '';
    _isChangingSink = true;
    try {
      await _applyToExistingAudioElements(
        deviceId,
        rollbackSinkId: previousSinkId,
      );
      _sinkId = deviceId;
    } finally {
      _isChangingSink = false;
      // The observer skips mutations during the asynchronous update, so
      // reconcile any audio elements created in that interval afterwards.
      unawaited(_applyToNewAudioElements());
    }
  }

  void _observeAudioElements() {
    final container = web.document.getElementById('livekit_audio_container');
    if (container != null) {
      _observeAudioContainer(container);
      return;
    }

    final body = web.document.body;
    if (body == null) return;
    _audioContainerObserver = web.MutationObserver(
      ((JSArray<web.MutationRecord> _, web.MutationObserver _) {
        final container = web.document.getElementById(
          'livekit_audio_container',
        );
        if (container == null) return;
        _audioContainerObserver?.disconnect();
        _audioContainerObserver = null;
        _observeAudioContainer(container);
      }).toJS,
    )..observe(body, web.MutationObserverInit(childList: true));
  }

  void _observeAudioContainer(web.Element container) {
    _audioElementsObserver?.disconnect();
    _audioElementsObserver = web.MutationObserver(
      ((JSArray<web.MutationRecord> _, web.MutationObserver _) {
        unawaited(_applyToNewAudioElements());
      }).toJS,
    )..observe(container, web.MutationObserverInit(childList: true));
  }

  Future<void> _applyToNewAudioElements() async {
    final sinkId = _sinkId;
    if (_isChangingSink || !_started || sinkId == null || sinkId.isEmpty) {
      return;
    }
    try {
      await _applyToExistingAudioElements(sinkId, rollbackSinkId: '');
    } catch (error, stackTrace) {
      logger.w(
        'Failed to apply the selected browser audio output to a new track.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _applyToExistingAudioElements(
    String deviceId, {
    required String rollbackSinkId,
  }) async {
    final container = web.document.getElementById('livekit_audio_container');
    if (container == null) return;

    final changed = <web.HTMLAudioElement>[];
    final elements = container.querySelectorAll('audio');
    try {
      for (var index = 0; index < elements.length; index++) {
        final element = elements.item(index);
        if (element == null || !element.instanceOfString('HTMLAudioElement')) {
          continue;
        }
        final audio = element as web.HTMLAudioElement;
        if (audio.sinkId == deviceId) continue;
        await _setSinkId(audio, deviceId);
        changed.add(audio);
      }
    } catch (_) {
      try {
        await Future.wait([
          for (final audio in changed) _setSinkId(audio, rollbackSinkId),
        ]);
      } catch (error, stackTrace) {
        logger.w(
          'Failed to restore browser audio outputs after a sink change failed.',
          error: error,
          stackTrace: stackTrace,
        );
      }
      rethrow;
    }
  }

  Future<void> _setSinkId(web.HTMLAudioElement audio, String deviceId) async {
    final promise = audio.callMethod<JSPromise<JSAny?>>(
      'setSinkId'.toJS,
      deviceId.toJS,
    );
    await promise.toDart;
  }
}
