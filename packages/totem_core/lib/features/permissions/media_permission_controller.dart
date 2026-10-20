import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/features/permissions/adapters/media_permission_adapter.dart';
import 'package:totem_core/features/permissions/classify.dart';
import 'package:totem_core/features/permissions/model.dart';
import 'package:totem_core/features/permissions/platform_info.dart';
import 'package:totem_core/features/permissions/policy.dart';

/// The single source of truth for camera and microphone permission.
///
/// Kept alive for the life of the app, so a permission learned while nothing
/// is watching (such as a grant made before pre-join renders) is never lost
/// (X1).
final mediaPermissionControllerProvider =
    NotifierProvider<MediaPermissionController, MediaPermissions?>(
      MediaPermissionController.new,
    );

/// Holds [MediaPermissions], or null until the first query completes.
///
/// Only permission: whether a device works is kept by whoever captures it.
/// Inputs are permission queries (on start, on app resume, and on platform
/// change events), native permission requests, and captures, which prove a
/// grant or reveal a refusal. Queries are only hints and never override a
/// request or capture outcome unless the platform's answer changed; see
/// `reconcileQuery`.
class MediaPermissionController extends Notifier<MediaPermissions?> {
  late MediaPermissionAdapter _adapter;
  final _lastQuery = <MediaKind, MediaPermission>{};
  final _requests = <MediaKind, Future<MediaPermission>>{};
  Future<void>? _refreshing;
  bool _refreshAgain = false;

  @override
  MediaPermissions? build() {
    _adapter = ref.watch(mediaPermissionAdapterProvider);
    final changes = _adapter.changes.listen((_) => unawaited(refresh()));
    // Settings changes happen while the app is in the background (X5), and
    // web tabs regain visibility through the same lifecycle (WS1).
    final lifecycle = AppLifecycleListener(
      onResume: () => unawaited(refresh()),
    );
    ref.onDispose(() {
      unawaited(changes.cancel());
      lifecycle.dispose();
    });
    unawaited(Future.microtask(refresh));
    return null;
  }

  PlatformInfo get platform => ref.read(platformInfoProvider);

  MediaPermissions get _current => state ?? const MediaPermissions();

  /// [kind]'s permission, unknown until the first query completes.
  MediaPermission permissionOf(MediaKind kind) => _current[kind];

  /// Re-queries both devices.
  ///
  /// A call made while a refresh is running schedules one more pass, so the
  /// final state always reflects the platform's latest answer. This matters
  /// when an OS prompt's resume overlaps a request (I8).
  Future<void> refresh() {
    final running = _refreshing;
    if (running != null) {
      _refreshAgain = true;
      return running;
    }
    return _refreshing = _refreshUntilSettled().whenComplete(
      () => _refreshing = null,
    );
  }

  Future<void> _refreshUntilSettled() async {
    do {
      _refreshAgain = false;
      final queries = await Future.wait(MediaKind.values.map(_query));
      if (!ref.mounted) return;
      var next = _current;
      for (final (index, kind) in MediaKind.values.indexed) {
        final query = queries[index];
        if (query == null) continue;
        next = next.withPermission(
          kind,
          reconcileQuery(
            current: next[kind],
            previousQuery: _lastQuery[kind],
            query: query,
          ),
        );
        _lastQuery[kind] = query;
      }
      state = next;
    } while (_refreshAgain && ref.mounted);
  }

  Future<MediaPermission?> _query(MediaKind kind) async {
    try {
      return await _adapter.query(kind);
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to query ${kind.name} permission',
      );
      return null;
    }
  }

  /// Shows the OS prompt for [kind] and returns the resulting permission.
  ///
  /// Concurrent calls for one device share a single prompt. On web there is
  /// no separate prompt (WS2), and the current permission is returned.
  Future<MediaPermission> request(MediaKind kind) =>
      _requests[kind] ??= _request(kind).whenComplete(() {
        // Block body: returning the removed future would make whenComplete
        // wait on itself.
        _requests.remove(kind);
      });

  Future<MediaPermission> _request(MediaKind kind) async {
    MediaPermission? result;
    try {
      result = await _adapter.request(kind);
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to request ${kind.name} permission',
      );
    }
    if (!ref.mounted) return result ?? MediaPermission.unknown;
    if (result != null) _set(kind, result);
    return _current[kind];
  }

  /// A capture of [kind] started, which proves it's allowed, whatever a
  /// stale query says (WS1).
  void recordCaptureSuccess(MediaKind kind) =>
      _set(kind, MediaPermission.granted);

  /// Classifies why capturing [kind] failed, records a refusal, and reports
  /// the error: as expected when it's a known failure, otherwise as a bug.
  /// Unknown errors are treated as a device that failed (X4).
  Future<CaptureFailure> recordCaptureFailure(
    MediaKind kind,
    Object error,
    StackTrace stackTrace,
  ) async {
    final platform = this.platform;
    final needsDeviceList =
        platform is WebPlatform && captureErrorName(error) == 'NotFoundError';
    final deviceListed = needsDeviceList && await _hasDevice(kind);
    final failure = classifyCaptureError(
      error,
      platform,
      deviceListed: deviceListed,
    );
    ErrorHandler.report(
      error,
      stackTrace: stackTrace,
      message: 'Failed to capture ${kind.name}',
      disposition: failure == null
          ? ErrorDisposition.unexpected
          : ErrorDisposition.expected,
    );
    switch (failure) {
      case PermissionRefused(:final permission):
        _set(kind, permission);
      // The platform didn't refuse this time, so an earlier refusal no longer
      // holds and mustn't outrank the device's problem in recovery. Some
      // device failures come before the permission check, so it's unknown
      // rather than granted.
      case DeviceFailed() when _refusals.contains(_current[kind]):
        _set(kind, MediaPermission.unknown);
      case DeviceFailed() || null:
        break;
    }
    return failure ?? const DeviceFailed(DeviceProblem.failed);
  }

  static const Set<MediaPermission> _refusals = {
    MediaPermission.denied,
    MediaPermission.blocked,
    MediaPermission.blockedBySystem,
  };

  void _set(MediaKind kind, MediaPermission permission) {
    if (ref.mounted) state = _current.withPermission(kind, permission);
  }

  Future<bool> _hasDevice(MediaKind kind) async {
    try {
      return await _adapter.hasDevice(kind);
    } catch (_) {
      return false;
    }
  }

  Future<bool> openSettings() async {
    try {
      return await _adapter.openSettings();
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to open app settings',
      );
      return false;
    }
  }
}
