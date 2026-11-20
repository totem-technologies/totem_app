// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:degenerate_runtime/degenerate_runtime.dart';

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
    this.admissionBlockReason = const Omittable.absent(),
  });

  factory AdmissionJoinState.fromJson(Map<String, dynamic> json) {
    return AdmissionJoinState(
      requestId: json['request_id'] as String,
      attemptId: json['attempt_id'] as String,
      status: json['status'] as String,
      durableState: json['durable_state'] as String,
      approvalRequired: json['approval_required'] as bool,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      permissions: AdmissionJoinStatePermissions.fromJson(
        json['permissions'] as String,
      ),
      permissionSync: json['permission_sync'] as String,
      revision: (json['revision'] as num).toInt(),
      admissionBlockReason: json.containsKey('admission_block_reason')
          ? Omittable(json['admission_block_reason'] as String?)
          : const Omittable.absent(),
    );
  }

  final String requestId;

  final String attemptId;

  final String status;

  final String durableState;

  final bool approvalRequired;

  final DateTime expiresAt;

  final AdmissionJoinStatePermissions permissions;

  final String permissionSync;

  final int revision;

  final Omittable<String?> admissionBlockReason;

  Map<String, dynamic> toJson() {
    return {
      'request_id': requestId,
      'attempt_id': attemptId,
      'status': status,
      'durable_state': durableState,
      'approval_required': approvalRequired,
      'expires_at': expiresAt.toIso8601String(),
      'permissions': permissions.toJson(),
      'permission_sync': permissionSync,
      'revision': revision,
      if (admissionBlockReason.isPresent)
        'admission_block_reason': admissionBlockReason.value,
    };
  }

  static bool canParse(Map<String, dynamic> json) {
    return json.containsKey('request_id') &&
        json['request_id'] is String &&
        json.containsKey('attempt_id') &&
        json['attempt_id'] is String &&
        json.containsKey('status') &&
        json['status'] is String &&
        json.containsKey('durable_state') &&
        json['durable_state'] is String &&
        json.containsKey('approval_required') &&
        json['approval_required'] is bool &&
        json.containsKey('expires_at') &&
        json['expires_at'] is String &&
        json.containsKey('permissions') &&
        json.containsKey('permission_sync') &&
        json['permission_sync'] is String &&
        json.containsKey('revision') &&
        json['revision'] is num;
  }

  AdmissionJoinState copyWith({
    String? requestId,
    String? attemptId,
    String? status,
    String? durableState,
    bool? approvalRequired,
    DateTime? expiresAt,
    AdmissionJoinStatePermissions? permissions,
    String? permissionSync,
    int? revision,
    Omittable<String?>? admissionBlockReason,
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
            admissionBlockReason == other.admissionBlockReason;
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
    );
  }

  @override
  String toString() {
    return 'AdmissionJoinState(requestId: $requestId, attemptId: $attemptId, status: $status, durableState: $durableState, approvalRequired: $approvalRequired, expiresAt: $expiresAt, permissions: $permissions, permissionSync: $permissionSync, revision: $revision, admissionBlockReason: $admissionBlockReason)';
  }
}
