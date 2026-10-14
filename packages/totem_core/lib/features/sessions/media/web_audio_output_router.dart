import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:totem_core/features/sessions/media/local_media.dart';

import 'package:totem_core/features/sessions/media/web_audio_output_gateway_stub.dart'
    if (dart.library.js_interop) 'package:totem_core/features/sessions/media/web_audio_output_gateway_web.dart';

/// Browser boundary for selecting the sink of LiveKit's existing audio
/// elements. The web implementation owns browser listeners and releases them
/// when [WebAudioOutputRouter.stop] runs.
abstract interface class WebAudioOutputGateway {
  bool get supportsSelection;
  bool get supportsOutputChooser;

  Stream<void> get changes;

  Future<void> start();
  Future<void> stop();
  Future<List<MediaDeviceInfo>> audioOutputs();
  Future<MediaDeviceInfo> requestAudioOutput();
  Future<void> setSinkId(String deviceId);
}

WebAudioOutputGateway createWebAudioOutputGateway() =>
    createWebAudioOutputGatewayImplementation();

/// Keeps browser sink selection separate from native audio-session routing.
///
/// A null [selectedDeviceId] means browser-default output. That deliberately
/// avoids pinning mobile web playback to a device id which can become stale
/// after a headset is connected or disconnected.
class WebAudioOutputRouter {
  new({WebAudioOutputGateway? gateway})
    : _gateway = gateway ?? createWebAudioOutputGateway();

  final WebAudioOutputGateway _gateway;
  StreamSubscription<void>? _changesSubscription;
  Future<void> _operations = Future.value();
  VoidCallback? _onChanged;
  String? _selectedDeviceId;
  bool _started = false;
  bool _reconcileScheduled = false;

  bool get supportsSelection => _gateway.supportsSelection;
  bool get supportsOutputChooser =>
      supportsSelection && _gateway.supportsOutputChooser;
  String? get selectedDeviceId => _selectedDeviceId;

  @visibleForTesting
  Future<void> get pending => _operations;

  Future<void> start(VoidCallback onChanged) async {
    if (_started || !supportsSelection) return;
    _started = true;
    _onChanged = onChanged;
    await _gateway.start();
    if (!_started) {
      await _gateway.stop();
      return;
    }
    _changesSubscription = _gateway.changes.listen((_) {
      if (_selectedDeviceId == null || _reconcileScheduled || !_started) {
        return;
      }
      _reconcileScheduled = true;
      scheduleMicrotask(() {
        _reconcileScheduled = false;
        unawaited(_enqueue(_restoreDefaultIfSelectionDisappeared));
      });
    });
  }

  /// Opens the browser chooser before its first await so the call retains the
  /// user's transient activation. Selection itself is applied after the
  /// browser returns and the output list has refreshed.
  Future<void> requestAudioOutput() async {
    if (!supportsOutputChooser) {
      throw UnsupportedError('Browser audio-output selection is unavailable.');
    }
    final device = await _gateway.requestAudioOutput();
    await select(device);
  }

  Future<void> select(MediaDeviceInfo device) {
    if (!supportsSelection) {
      return Future.error(
        UnsupportedError('Browser audio-output selection is unavailable.'),
      );
    }
    return _enqueue(() async {
      final outputs = await _gateway.audioOutputs();
      if (!outputs.any(
        (output) =>
            output.kind == MediaDeviceKind.audioOutput &&
            output.id == device.id,
      )) {
        throw StateError('The selected audio output is no longer available.');
      }

      final selectedDeviceId = device.id == 'default' ? null : device.id;
      await _gateway.setSinkId(selectedDeviceId ?? '');
      _selectedDeviceId = selectedDeviceId;
      _onChanged?.call();
    });
  }

  Future<void> _restoreDefaultIfSelectionDisappeared() async {
    final selectedDeviceId = _selectedDeviceId;
    if (selectedDeviceId == null) return;

    final outputs = await _gateway.audioOutputs();
    if (outputs.any((output) => output.id == selectedDeviceId)) return;

    await _gateway.setSinkId('');
    _selectedDeviceId = null;
    _onChanged?.call();
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final result = _operations.then((_) => operation());
    _operations = result.catchError((Object _) {});
    return result;
  }

  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    await _changesSubscription?.cancel();
    _changesSubscription = null;
    _selectedDeviceId = null;
    await _gateway.stop();
  }
}
