// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:degenerate_runtime/degenerate_runtime.dart';

import 'admission_readiness.dart';

@immutable
final class AdmissionJoinStateStatus {
  const AdmissionJoinStateStatus._(this.value);

  factory AdmissionJoinStateStatus.fromJson(String json) {
    return switch (json) {
      'pending' => pending,
      'granting' => granting,
      'admitted' => admitted,
      'declined' => declined,
      'permanently_declined' => permanentlyDeclined,
      'cancelled' => cancelled,
      'expired' => expired,
      'superseded' => superseded,
      'revoked' => revoked,
      'failed' => failed,
      _ => AdmissionJoinStateStatus._(json),
    };
  }

  static const AdmissionJoinStateStatus pending = AdmissionJoinStateStatus._(
    'pending',
  );

  static const AdmissionJoinStateStatus granting = AdmissionJoinStateStatus._(
    'granting',
  );

  static const AdmissionJoinStateStatus admitted = AdmissionJoinStateStatus._(
    'admitted',
  );

  static const AdmissionJoinStateStatus declined = AdmissionJoinStateStatus._(
    'declined',
  );

  static const AdmissionJoinStateStatus permanentlyDeclined =
      AdmissionJoinStateStatus._('permanently_declined');

  static const AdmissionJoinStateStatus cancelled = AdmissionJoinStateStatus._(
    'cancelled',
  );

  static const AdmissionJoinStateStatus expired = AdmissionJoinStateStatus._(
    'expired',
  );

  static const AdmissionJoinStateStatus superseded = AdmissionJoinStateStatus._(
    'superseded',
  );

  static const AdmissionJoinStateStatus revoked = AdmissionJoinStateStatus._(
    'revoked',
  );

  static const AdmissionJoinStateStatus failed = AdmissionJoinStateStatus._(
    'failed',
  );

  static const List<AdmissionJoinStateStatus> values = [
    pending,
    granting,
    admitted,
    declined,
    permanentlyDeclined,
    cancelled,
    expired,
    superseded,
    revoked,
    failed,
  ];

  final String value;

  String toJson() {
    return value;
  }

  /// Whether this value is unknown (not defined in the OpenAPI spec).
  bool get isUnknown {
    return !values.contains(this);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AdmissionJoinStateStatus && other.value == value;
  }

  @override
  int get hashCode {
    return value.hashCode;
  }

  @override
  String toString() {
    return 'AdmissionJoinStateStatus($value)';
  }
}

@immutable
final class AdmissionJoinStateDurableState {
  const AdmissionJoinStateDurableState._(this.value);

  factory AdmissionJoinStateDurableState.fromJson(String json) {
    return switch (json) {
      'none' => none,
      'admitted' => admitted,
      'permanently_declined' => permanentlyDeclined,
      'revoked' => revoked,
      _ => AdmissionJoinStateDurableState._(json),
    };
  }

  static const AdmissionJoinStateDurableState none =
      AdmissionJoinStateDurableState._('none');

  static const AdmissionJoinStateDurableState admitted =
      AdmissionJoinStateDurableState._('admitted');

  static const AdmissionJoinStateDurableState permanentlyDeclined =
      AdmissionJoinStateDurableState._('permanently_declined');

  static const AdmissionJoinStateDurableState revoked =
      AdmissionJoinStateDurableState._('revoked');

  static const List<AdmissionJoinStateDurableState> values = [
    none,
    admitted,
    permanentlyDeclined,
    revoked,
  ];

  final String value;

  String toJson() {
    return value;
  }

  /// Whether this value is unknown (not defined in the OpenAPI spec).
  bool get isUnknown {
    return !values.contains(this);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AdmissionJoinStateDurableState && other.value == value;
  }

  @override
  int get hashCode {
    return value.hashCode;
  }

  @override
  String toString() {
    return 'AdmissionJoinStateDurableState($value)';
  }
}

@immutable
final class AdmissionJoinStatePermissions {
  const AdmissionJoinStatePermissions._(this.value);

  factory AdmissionJoinStatePermissions.fromJson(String json) {
    return switch (json) {
      'waiting' => waiting,
      'admitted' => admitted,
      _ => AdmissionJoinStatePermissions._(json),
    };
  }

  static const AdmissionJoinStatePermissions waiting =
      AdmissionJoinStatePermissions._('waiting');

  static const AdmissionJoinStatePermissions admitted =
      AdmissionJoinStatePermissions._('admitted');

  static const List<AdmissionJoinStatePermissions> values = [waiting, admitted];

  final String value;

  String toJson() {
    return value;
  }

  /// Whether this value is unknown (not defined in the OpenAPI spec).
  bool get isUnknown {
    return !values.contains(this);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AdmissionJoinStatePermissions && other.value == value;
  }

  @override
  int get hashCode {
    return value.hashCode;
  }

  @override
  String toString() {
    return 'AdmissionJoinStatePermissions($value)';
  }
}

@immutable
final class AdmissionJoinStatePermissionSync {
  const AdmissionJoinStatePermissionSync._(this.value);

  factory AdmissionJoinStatePermissionSync.fromJson(String json) {
    return switch (json) {
      'pending' => pending,
      'applied' => applied,
      'room_missing' => roomMissing,
      'participant_missing' => participantMissing,
      'unavailable' => unavailable,
      'timeout' => timeout,
      'identity_replaced' => identityReplaced,
      'permission_mismatch' => permissionMismatch,
      'stale_operation' => staleOperation,
      'lease_recovered' => leaseRecovered,
      'permission_pending' => permissionPending,
      _ => AdmissionJoinStatePermissionSync._(json),
    };
  }

  static const AdmissionJoinStatePermissionSync pending =
      AdmissionJoinStatePermissionSync._('pending');

  static const AdmissionJoinStatePermissionSync applied =
      AdmissionJoinStatePermissionSync._('applied');

  static const AdmissionJoinStatePermissionSync roomMissing =
      AdmissionJoinStatePermissionSync._('room_missing');

  static const AdmissionJoinStatePermissionSync participantMissing =
      AdmissionJoinStatePermissionSync._('participant_missing');

  static const AdmissionJoinStatePermissionSync unavailable =
      AdmissionJoinStatePermissionSync._('unavailable');

  static const AdmissionJoinStatePermissionSync timeout =
      AdmissionJoinStatePermissionSync._('timeout');

  static const AdmissionJoinStatePermissionSync identityReplaced =
      AdmissionJoinStatePermissionSync._('identity_replaced');

  static const AdmissionJoinStatePermissionSync permissionMismatch =
      AdmissionJoinStatePermissionSync._('permission_mismatch');

  static const AdmissionJoinStatePermissionSync staleOperation =
      AdmissionJoinStatePermissionSync._('stale_operation');

  static const AdmissionJoinStatePermissionSync leaseRecovered =
      AdmissionJoinStatePermissionSync._('lease_recovered');

  static const AdmissionJoinStatePermissionSync permissionPending =
      AdmissionJoinStatePermissionSync._('permission_pending');

  static const List<AdmissionJoinStatePermissionSync> values = [
    pending,
    applied,
    roomMissing,
    participantMissing,
    unavailable,
    timeout,
    identityReplaced,
    permissionMismatch,
    staleOperation,
    leaseRecovered,
    permissionPending,
  ];

  final String value;

  String toJson() {
    return value;
  }

  /// Whether this value is unknown (not defined in the OpenAPI spec).
  bool get isUnknown {
    return !values.contains(this);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AdmissionJoinStatePermissionSync && other.value == value;
  }

  @override
  int get hashCode {
    return value.hashCode;
  }

  @override
  String toString() {
    return 'AdmissionJoinStatePermissionSync($value)';
  }
}

@immutable
final class AdmissionJoinStateAdmissionBlockReason {
  const AdmissionJoinStateAdmissionBlockReason._(this.value);

  factory AdmissionJoinStateAdmissionBlockReason.fromJson(String json) {
    return switch (json) {
      'requires_reapproval' => requiresReapproval,
      'permanently_declined' => permanentlyDeclined,
      'admission_full' => admissionFull,
      _ => AdmissionJoinStateAdmissionBlockReason._(json),
    };
  }

  static const AdmissionJoinStateAdmissionBlockReason requiresReapproval =
      AdmissionJoinStateAdmissionBlockReason._('requires_reapproval');

  static const AdmissionJoinStateAdmissionBlockReason permanentlyDeclined =
      AdmissionJoinStateAdmissionBlockReason._('permanently_declined');

  static const AdmissionJoinStateAdmissionBlockReason admissionFull =
      AdmissionJoinStateAdmissionBlockReason._('admission_full');

  static const List<AdmissionJoinStateAdmissionBlockReason> values = [
    requiresReapproval,
    permanentlyDeclined,
    admissionFull,
  ];

  final String value;

  String toJson() {
    return value;
  }

  /// Whether this value is unknown (not defined in the OpenAPI spec).
  bool get isUnknown {
    return !values.contains(this);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AdmissionJoinStateAdmissionBlockReason && other.value == value;
  }

  @override
  int get hashCode {
    return value.hashCode;
  }

  @override
  String toString() {
    return 'AdmissionJoinStateAdmissionBlockReason($value)';
  }
}

@immutable
final class AdmissionJoinState {
  const AdmissionJoinState({
    required this.requestId,
    required this.attemptId,
    required this.status,
    required this.durableState,
    required this.approvalRequired,
    required this.expiresAt,
    required this.permissions,
    required this.permissionSync,
    required this.revision,
    required this.observedAt,
    required this.readiness,
    this.admissionBlockReason = const Omittable.absent(),
  });

  factory AdmissionJoinState.fromJson(Map<String, dynamic> json) {
    return AdmissionJoinState(
      requestId: json['request_id'] as String,
      attemptId: json['attempt_id'] as String,
      status: AdmissionJoinStateStatus.fromJson(json['status'] as String),
      durableState: AdmissionJoinStateDurableState.fromJson(
        json['durable_state'] as String,
      ),
      approvalRequired: json['approval_required'] as bool,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      permissions: AdmissionJoinStatePermissions.fromJson(
        json['permissions'] as String,
      ),
      permissionSync: AdmissionJoinStatePermissionSync.fromJson(
        json['permission_sync'] as String,
      ),
      revision: (json['revision'] as num).toInt(),
      admissionBlockReason: json.containsKey('admission_block_reason')
          ? Omittable(
              json['admission_block_reason'] != null
                  ? AdmissionJoinStateAdmissionBlockReason.fromJson(
                      json['admission_block_reason'] as String,
                    )
                  : null,
            )
          : const Omittable.absent(),
      observedAt: DateTime.parse(json['observed_at'] as String),
      readiness: AdmissionReadiness.fromJson(
        json['readiness'] as Map<String, dynamic>,
      ),
    );
  }

  final String requestId;

  final String attemptId;

  final AdmissionJoinStateStatus status;

  final AdmissionJoinStateDurableState durableState;

  final bool approvalRequired;

  final DateTime expiresAt;

  final AdmissionJoinStatePermissions permissions;

  final AdmissionJoinStatePermissionSync permissionSync;

  final int revision;

  final Omittable<AdmissionJoinStateAdmissionBlockReason?> admissionBlockReason;

  final DateTime observedAt;

  final AdmissionReadiness readiness;

  Map<String, dynamic> toJson() {
    return {
      'request_id': requestId,
      'attempt_id': attemptId,
      'status': status.toJson(),
      'durable_state': durableState.toJson(),
      'approval_required': approvalRequired,
      'expires_at': expiresAt.toIso8601String(),
      'permissions': permissions.toJson(),
      'permission_sync': permissionSync.toJson(),
      'revision': revision,
      if (admissionBlockReason.isPresent)
        'admission_block_reason': admissionBlockReason.value?.toJson(),
      'observed_at': observedAt.toIso8601String(),
      'readiness': readiness.toJson(),
    };
  }

  static bool canParse(Map<String, dynamic> json) {
    return json.containsKey('request_id') &&
        json['request_id'] is String &&
        json.containsKey('attempt_id') &&
        json['attempt_id'] is String &&
        json.containsKey('status') &&
        json.containsKey('durable_state') &&
        json.containsKey('approval_required') &&
        json['approval_required'] is bool &&
        json.containsKey('expires_at') &&
        json['expires_at'] is String &&
        json.containsKey('permissions') &&
        json.containsKey('permission_sync') &&
        json.containsKey('revision') &&
        json['revision'] is num &&
        json.containsKey('observed_at') &&
        json['observed_at'] is String &&
        json.containsKey('readiness');
  }

  AdmissionJoinState copyWith({
    String? requestId,
    String? attemptId,
    AdmissionJoinStateStatus? status,
    AdmissionJoinStateDurableState? durableState,
    bool? approvalRequired,
    DateTime? expiresAt,
    AdmissionJoinStatePermissions? permissions,
    AdmissionJoinStatePermissionSync? permissionSync,
    int? revision,
    Omittable<AdmissionJoinStateAdmissionBlockReason?>? admissionBlockReason,
    DateTime? observedAt,
    AdmissionReadiness? readiness,
  }) {
    return AdmissionJoinState(
      requestId: requestId ?? this.requestId,
      attemptId: attemptId ?? this.attemptId,
      status: status ?? this.status,
      durableState: durableState ?? this.durableState,
      approvalRequired: approvalRequired ?? this.approvalRequired,
      expiresAt: expiresAt ?? this.expiresAt,
      permissions: permissions ?? this.permissions,
      permissionSync: permissionSync ?? this.permissionSync,
      revision: revision ?? this.revision,
      admissionBlockReason: admissionBlockReason ?? this.admissionBlockReason,
      observedAt: observedAt ?? this.observedAt,
      readiness: readiness ?? this.readiness,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AdmissionJoinState &&
            requestId == other.requestId &&
            attemptId == other.attemptId &&
            status == other.status &&
            durableState == other.durableState &&
            approvalRequired == other.approvalRequired &&
            expiresAt == other.expiresAt &&
            permissions == other.permissions &&
            permissionSync == other.permissionSync &&
            revision == other.revision &&
            admissionBlockReason == other.admissionBlockReason &&
            observedAt == other.observedAt &&
            readiness == other.readiness;
  }

  @override
  int get hashCode {
    return Object.hash(
      requestId,
      attemptId,
      status,
      durableState,
      approvalRequired,
      expiresAt,
      permissions,
      permissionSync,
      revision,
      admissionBlockReason,
      observedAt,
      readiness,
    );
  }

  @override
  String toString() {
    return 'AdmissionJoinState(requestId: $requestId, attemptId: $attemptId, status: $status, durableState: $durableState, approvalRequired: $approvalRequired, expiresAt: $expiresAt, permissions: $permissions, permissionSync: $permissionSync, revision: $revision, admissionBlockReason: $admissionBlockReason, observedAt: $observedAt, readiness: $readiness)';
  }
}
