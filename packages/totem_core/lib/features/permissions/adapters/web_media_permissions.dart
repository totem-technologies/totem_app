import 'dart:async';
import 'dart:js_interop';

import 'package:totem_core/features/permissions/adapters/media_permission_adapter.dart';
import 'package:totem_core/features/permissions/classify.dart';
import 'package:totem_core/features/permissions/model.dart';
import 'package:web/web.dart' as web;

MediaPermissionAdapter createWebMediaPermissions() => WebMediaPermissions();

/// Browsers, through `navigator.permissions` and `enumerateDevices`.
///
/// Never calls `getUserMedia`: capture is the permission request on web, and
/// a second capture of the same kind mutes the first on WebKit (WS2).
class WebMediaPermissions implements MediaPermissionAdapter {
  final _changes = StreamController<void>.broadcast();

  /// The statuses whose change events are observed, kept so they stay
  /// alive while they have a handler.
  final _watched = <MediaKind, web.PermissionStatus>{};

  String _name(MediaKind kind) => switch (kind) {
    MediaKind.camera => 'camera',
    MediaKind.microphone => 'microphone',
  };

  @override
  Future<MediaPermission?> query(MediaKind kind) async {
    try {
      final descriptor = {'name': _name(kind)}.jsify()! as JSObject;
      final status = await web.window.navigator.permissions
          .query(descriptor)
          .toDart;
      _watch(kind, status);
      return permissionFromWebState(status.state);
    } catch (_) {
      // Firefox before 132 rejects these names, and insecure contexts have no
      // permissions object. Both leave capture to decide (W1, W4, WF1).
      return null;
    }
  }

  void _watch(MediaKind kind, web.PermissionStatus status) {
    if (_watched.containsKey(kind)) return;
    _watched[kind] = status;
    // Chrome fires this reliably; Safari may not, so the controller also
    // refreshes when the page becomes visible again (WC1, WS1).
    status.onchange = ((web.Event _) {
      if (!_changes.isClosed) _changes.add(null);
    }).toJS;
  }

  @override
  Future<MediaPermission?> request(MediaKind kind) async => null;

  @override
  Future<bool> openSettings() async => false;

  @override
  Future<bool> hasDevice(MediaKind kind) async {
    final deviceKind = switch (kind) {
      MediaKind.camera => 'videoinput',
      MediaKind.microphone => 'audioinput',
    };
    try {
      final devices = await web.window.navigator.mediaDevices
          .enumerateDevices()
          .toDart;
      return devices.toDart.any((device) => device.kind == deviceKind);
    } catch (_) {
      return false;
    }
  }

  @override
  Stream<void> get changes => _changes.stream;

  @override
  void dispose() {
    for (final status in _watched.values) {
      status.onchange = null;
    }
    _watched.clear();
    unawaited(_changes.close());
  }
}
