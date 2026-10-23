// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_permission_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The single source of truth for camera and microphone permission. Holds
/// [MediaPermissions], or null until the first query completes.
///
/// Kept alive for the life of the app, so a permission learned while nothing
/// is watching (such as a grant made before pre-join renders, or an Android
/// refusal its status no longer shows) is never lost (X1, A2).
///
/// Only permission: whether a device works is kept by whoever captures it.
/// Inputs are permission queries (on start, on app resume, and on platform
/// change events), native permission requests, and captures, which prove a
/// grant or reveal a refusal. Queries are only hints and never override a
/// request or capture outcome unless the platform's answer changed; see
/// `reconcileQuery`.

@ProviderFor(MediaPermissionController)
final mediaPermissionControllerProvider = MediaPermissionControllerProvider._();

/// The single source of truth for camera and microphone permission. Holds
/// [MediaPermissions], or null until the first query completes.
///
/// Kept alive for the life of the app, so a permission learned while nothing
/// is watching (such as a grant made before pre-join renders, or an Android
/// refusal its status no longer shows) is never lost (X1, A2).
///
/// Only permission: whether a device works is kept by whoever captures it.
/// Inputs are permission queries (on start, on app resume, and on platform
/// change events), native permission requests, and captures, which prove a
/// grant or reveal a refusal. Queries are only hints and never override a
/// request or capture outcome unless the platform's answer changed; see
/// `reconcileQuery`.
final class MediaPermissionControllerProvider
    extends $NotifierProvider<MediaPermissionController, MediaPermissions?> {
  /// The single source of truth for camera and microphone permission. Holds
  /// [MediaPermissions], or null until the first query completes.
  ///
  /// Kept alive for the life of the app, so a permission learned while nothing
  /// is watching (such as a grant made before pre-join renders, or an Android
  /// refusal its status no longer shows) is never lost (X1, A2).
  ///
  /// Only permission: whether a device works is kept by whoever captures it.
  /// Inputs are permission queries (on start, on app resume, and on platform
  /// change events), native permission requests, and captures, which prove a
  /// grant or reveal a refusal. Queries are only hints and never override a
  /// request or capture outcome unless the platform's answer changed; see
  /// `reconcileQuery`.
  MediaPermissionControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mediaPermissionControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mediaPermissionControllerHash();

  @$internal
  @override
  MediaPermissionController create() => MediaPermissionController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MediaPermissions? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MediaPermissions?>(value),
    );
  }
}

String _$mediaPermissionControllerHash() =>
    r'00a4b72f6be99ce5b74d0a77c2e4a467c4fbb2b3';

/// The single source of truth for camera and microphone permission. Holds
/// [MediaPermissions], or null until the first query completes.
///
/// Kept alive for the life of the app, so a permission learned while nothing
/// is watching (such as a grant made before pre-join renders, or an Android
/// refusal its status no longer shows) is never lost (X1, A2).
///
/// Only permission: whether a device works is kept by whoever captures it.
/// Inputs are permission queries (on start, on app resume, and on platform
/// change events), native permission requests, and captures, which prove a
/// grant or reveal a refusal. Queries are only hints and never override a
/// request or capture outcome unless the platform's answer changed; see
/// `reconcileQuery`.

abstract class _$MediaPermissionController
    extends $Notifier<MediaPermissions?> {
  MediaPermissions? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<MediaPermissions?, MediaPermissions?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<MediaPermissions?, MediaPermissions?>,
              MediaPermissions?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
