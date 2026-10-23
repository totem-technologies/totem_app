// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_permissions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(notificationPermissions)
final notificationPermissionsProvider = NotificationPermissionsProvider._();

final class NotificationPermissionsProvider
    extends
        $FunctionalProvider<
          NotificationPermissions,
          NotificationPermissions,
          NotificationPermissions
        >
    with $Provider<NotificationPermissions> {
  NotificationPermissionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationPermissionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationPermissionsHash();

  @$internal
  @override
  $ProviderElement<NotificationPermissions> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  NotificationPermissions create(Ref ref) {
    return notificationPermissions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NotificationPermissions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NotificationPermissions>(value),
    );
  }
}

String _$notificationPermissionsHash() =>
    r'ef425a2628b3e752f039b20fa6c693f5e699f0d2';
