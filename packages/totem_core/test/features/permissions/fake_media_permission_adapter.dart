import 'dart:async';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:totem_core/features/permissions/adapters/media_permission_adapter.dart';
import 'package:totem_core/features/permissions/model.dart';
import 'package:totem_core/features/permissions/platform_info.dart';

/// Overrides for tests that don't exercise permissions: an iOS app with the
/// camera and microphone already allowed.
List<Override> grantedMediaPermissionOverrides() => [
  platformInfoProvider.overrideWithValue(const IosApp()),
  mediaPermissionAdapterProvider.overrideWithValue(
    FakeMediaPermissionAdapter(),
  ),
];

/// A scriptable [MediaPermissionAdapter]: [queries] is what the platform
/// reports, and [requestResults] what its prompt returns.
class FakeMediaPermissionAdapter implements MediaPermissionAdapter {
  FakeMediaPermissionAdapter({
    MediaPermission? camera = MediaPermission.granted,
    MediaPermission? microphone = MediaPermission.granted,
    Map<MediaKind, MediaPermission?>? requestResults,
    this.devicesListed = true,
  }) : queries = {MediaKind.camera: camera, MediaKind.microphone: microphone},
       requestResults = requestResults ?? {};

  final Map<MediaKind, MediaPermission?> queries;
  final Map<MediaKind, MediaPermission?> requestResults;
  bool devicesListed;
  final requested = <MediaKind>[];
  int settingsOpened = 0;

  /// Holds queries until completed, to test what happens before they finish.
  Completer<void>? queryGate;

  final _changes = StreamController<void>.broadcast();

  /// Simulates the platform reporting a permission change on its own.
  void emitChange() => _changes.add(null);

  @override
  Future<MediaPermission?> query(MediaKind kind) async {
    await queryGate?.future;
    return queries[kind];
  }

  @override
  Future<MediaPermission?> request(MediaKind kind) async {
    requested.add(kind);
    final result = requestResults[kind];
    if (result != null) queries[kind] = result;
    return result;
  }

  @override
  Future<bool> openSettings() async {
    settingsOpened++;
    return true;
  }

  @override
  Future<bool> hasDevice(MediaKind kind) async => devicesListed;

  @override
  Stream<void> get changes => _changes.stream;

  @override
  void dispose() => unawaited(_changes.close());
}
