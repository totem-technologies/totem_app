// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:degenerate_runtime/degenerate_runtime.dart';
import 'public_user_schema.dart';

@immutable
final class ParticipantConnectionState {
  const ParticipantConnectionState._(this.value);

  factory ParticipantConnectionState.fromJson(String json) {
    return switch (json) {
      'connected' => connected,
      'disconnected' => disconnected,
      'unknown' => unknown,
      _ => ParticipantConnectionState._(json),
    };
  }

  static const ParticipantConnectionState connected =
      ParticipantConnectionState._('connected');

  static const ParticipantConnectionState disconnected =
      ParticipantConnectionState._('disconnected');

  static const ParticipantConnectionState unknown =
      ParticipantConnectionState._('unknown');

  static const List<ParticipantConnectionState> values = [
    connected,
    disconnected,
    unknown,
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
        other is ParticipantConnectionState && other.value == value;
  }

  @override
  int get hashCode {
    return value.hashCode;
  }

  @override
  String toString() {
    return 'ParticipantConnectionState($value)';
  }
}

@immutable
final class Participant {
  const Participant({
    required this.identity,
    required this.user,
    required this.admissionState,
    required this.admissionVersion,
    required this.status,
    required this.connectionState,
    required this.eligible,
    required this.returning,
    required this.sessionStarted,
    required this.lateArrival,
    required this.permissionStatus,
    required this.permissionRevision,
    this.requestId = const Omittable.absent(),
    this.attemptId = const Omittable.absent(),
    this.attemptVersion = const Omittable.absent(),
    this.requestedAt = const Omittable.absent(),
    this.expiresAt = const Omittable.absent(),
    this.approvedAt = const Omittable.absent(),
    this.activatedAt = const Omittable.absent(),
    this.connectedAt = const Omittable.absent(),
    this.connected = const Omittable.absent(),
    this.appliedPermissionRevision = const Omittable.absent(),
    this.lastError = const Omittable.absent(),
    this.nextRetryAt = const Omittable.absent(),
    this.decisionActor = const Omittable.absent(),
    this.admissionBlockReason = const Omittable.absent(),
  });

  factory Participant.fromJson(Map<String, dynamic> json) {
    return Participant(
      identity: json['identity'] as String,
      user: PublicUserSchema.fromJson(json['user'] as Map<String, dynamic>),
      admissionState: json['admission_state'] as String,
      admissionVersion: (json['admission_version'] as num).toInt(),
      requestId: json.containsKey('request_id')
          ? Omittable(json['request_id'] as String?)
          : const Omittable.absent(),
      attemptId: json.containsKey('attempt_id')
          ? Omittable(json['attempt_id'] as String?)
          : const Omittable.absent(),
      attemptVersion: json.containsKey('attempt_version')
          ? Omittable(
              json['attempt_version'] != null
                  ? (json['attempt_version'] as num).toInt()
                  : null,
            )
          : const Omittable.absent(),
      status: json['status'] as String,
      requestedAt: json.containsKey('requested_at')
          ? Omittable(
              json['requested_at'] != null
                  ? DateTime.parse(json['requested_at'] as String)
                  : null,
            )
          : const Omittable.absent(),
      expiresAt: json.containsKey('expires_at')
          ? Omittable(
              json['expires_at'] != null
                  ? DateTime.parse(json['expires_at'] as String)
                  : null,
            )
          : const Omittable.absent(),
      approvedAt: json.containsKey('approved_at')
          ? Omittable(
              json['approved_at'] != null
                  ? DateTime.parse(json['approved_at'] as String)
                  : null,
            )
          : const Omittable.absent(),
      activatedAt: json.containsKey('activated_at')
          ? Omittable(
              json['activated_at'] != null
                  ? DateTime.parse(json['activated_at'] as String)
                  : null,
            )
          : const Omittable.absent(),
      connectedAt: json.containsKey('connected_at')
          ? Omittable(
              json['connected_at'] != null
                  ? DateTime.parse(json['connected_at'] as String)
                  : null,
            )
          : const Omittable.absent(),
      connected: json.containsKey('connected')
          ? Omittable(json['connected'] as bool?)
          : const Omittable.absent(),
      connectionState: ParticipantConnectionState.fromJson(
        json['connection_state'] as String,
      ),
      eligible: json['eligible'] as bool,
      returning: json['returning'] as bool,
      sessionStarted: json['session_started'] as bool,
      lateArrival: json['late_arrival'] as bool,
      permissionStatus: json['permission_status'] as String,
      permissionRevision: (json['permission_revision'] as num).toInt(),
      appliedPermissionRevision: json.containsKey('applied_permission_revision')
          ? Omittable(
              json['applied_permission_revision'] != null
                  ? (json['applied_permission_revision'] as num).toInt()
                  : null,
            )
          : const Omittable.absent(),
      lastError: json.containsKey('last_error')
          ? Omittable(json['last_error'] as String?)
          : const Omittable.absent(),
      nextRetryAt: json.containsKey('next_retry_at')
          ? Omittable(
              json['next_retry_at'] != null
                  ? DateTime.parse(json['next_retry_at'] as String)
                  : null,
            )
          : const Omittable.absent(),
      decisionActor: json.containsKey('decision_actor')
          ? Omittable(json['decision_actor'] as String?)
          : const Omittable.absent(),
      admissionBlockReason: json.containsKey('admission_block_reason')
          ? Omittable(json['admission_block_reason'] as String?)
          : const Omittable.absent(),
    );
  }

  final String identity;

  final PublicUserSchema user;

  final String admissionState;

  final int admissionVersion;

  final Omittable<String?> requestId;

  final Omittable<String?> attemptId;

  final Omittable<int?> attemptVersion;

  final String status;

  final Omittable<DateTime?> requestedAt;

  final Omittable<DateTime?> expiresAt;

  final Omittable<DateTime?> approvedAt;

  final Omittable<DateTime?> activatedAt;

  final Omittable<DateTime?> connectedAt;

  final Omittable<bool?> connected;

  final ParticipantConnectionState connectionState;

  final bool eligible;

  final bool returning;

  final bool sessionStarted;

  final bool lateArrival;

  final String permissionStatus;

  final int permissionRevision;

  final Omittable<int?> appliedPermissionRevision;

  final Omittable<String?> lastError;

  final Omittable<DateTime?> nextRetryAt;

  final Omittable<String?> decisionActor;

  final Omittable<String?> admissionBlockReason;

  Map<String, dynamic> toJson() {
    return {
      'identity': identity,
      'user': user.toJson(),
      'admission_state': admissionState,
      'admission_version': admissionVersion,
      if (requestId.isPresent) 'request_id': requestId.value,
      if (attemptId.isPresent) 'attempt_id': attemptId.value,
      if (attemptVersion.isPresent) 'attempt_version': attemptVersion.value,
      'status': status,
      if (requestedAt.isPresent)
        'requested_at': requestedAt.value?.toIso8601String(),
      if (expiresAt.isPresent) 'expires_at': expiresAt.value?.toIso8601String(),
      if (approvedAt.isPresent)
        'approved_at': approvedAt.value?.toIso8601String(),
      if (activatedAt.isPresent)
        'activated_at': activatedAt.value?.toIso8601String(),
      if (connectedAt.isPresent)
        'connected_at': connectedAt.value?.toIso8601String(),
      if (connected.isPresent) 'connected': connected.value,
      'connection_state': connectionState.toJson(),
      'eligible': eligible,
      'returning': returning,
      'session_started': sessionStarted,
      'late_arrival': lateArrival,
      'permission_status': permissionStatus,
      'permission_revision': permissionRevision,
      if (appliedPermissionRevision.isPresent)
        'applied_permission_revision': appliedPermissionRevision.value,
      if (lastError.isPresent) 'last_error': lastError.value,
      if (nextRetryAt.isPresent)
        'next_retry_at': nextRetryAt.value?.toIso8601String(),
      if (decisionActor.isPresent) 'decision_actor': decisionActor.value,
      if (admissionBlockReason.isPresent)
        'admission_block_reason': admissionBlockReason.value,
    };
  }

  static bool canParse(Map<String, dynamic> json) {
    return json.containsKey('identity') &&
        json['identity'] is String &&
        json.containsKey('user') &&
        json.containsKey('admission_state') &&
        json['admission_state'] is String &&
        json.containsKey('admission_version') &&
        json['admission_version'] is num &&
        json.containsKey('status') &&
        json['status'] is String &&
        json.containsKey('connection_state') &&
        json.containsKey('eligible') &&
        json['eligible'] is bool &&
        json.containsKey('returning') &&
        json['returning'] is bool &&
        json.containsKey('session_started') &&
        json['session_started'] is bool &&
        json.containsKey('late_arrival') &&
        json['late_arrival'] is bool &&
        json.containsKey('permission_status') &&
        json['permission_status'] is String &&
        json.containsKey('permission_revision') &&
        json['permission_revision'] is num;
  }

  Participant copyWith({
    String? identity,
    PublicUserSchema? user,
    String? admissionState,
    int? admissionVersion,
    Omittable<String?>? requestId,
    Omittable<String?>? attemptId,
    Omittable<int?>? attemptVersion,
    String? status,
    Omittable<DateTime?>? requestedAt,
    Omittable<DateTime?>? expiresAt,
    Omittable<DateTime?>? approvedAt,
    Omittable<DateTime?>? activatedAt,
    Omittable<DateTime?>? connectedAt,
    Omittable<bool?>? connected,
    ParticipantConnectionState? connectionState,
    bool? eligible,
    bool? returning,
    bool? sessionStarted,
    bool? lateArrival,
    String? permissionStatus,
    int? permissionRevision,
    Omittable<int?>? appliedPermissionRevision,
    Omittable<String?>? lastError,
    Omittable<DateTime?>? nextRetryAt,
    Omittable<String?>? decisionActor,
    Omittable<String?>? admissionBlockReason,
  }) {
    return Participant(
      identity: identity ?? this.identity,
      user: user ?? this.user,
      admissionState: admissionState ?? this.admissionState,
      admissionVersion: admissionVersion ?? this.admissionVersion,
      requestId: requestId ?? this.requestId,
      attemptId: attemptId ?? this.attemptId,
      attemptVersion: attemptVersion ?? this.attemptVersion,
      status: status ?? this.status,
      requestedAt: requestedAt ?? this.requestedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      approvedAt: approvedAt ?? this.approvedAt,
      activatedAt: activatedAt ?? this.activatedAt,
      connectedAt: connectedAt ?? this.connectedAt,
      connected: connected ?? this.connected,
      connectionState: connectionState ?? this.connectionState,
      eligible: eligible ?? this.eligible,
      returning: returning ?? this.returning,
      sessionStarted: sessionStarted ?? this.sessionStarted,
      lateArrival: lateArrival ?? this.lateArrival,
      permissionStatus: permissionStatus ?? this.permissionStatus,
      permissionRevision: permissionRevision ?? this.permissionRevision,
      appliedPermissionRevision:
          appliedPermissionRevision ?? this.appliedPermissionRevision,
      lastError: lastError ?? this.lastError,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      decisionActor: decisionActor ?? this.decisionActor,
      admissionBlockReason: admissionBlockReason ?? this.admissionBlockReason,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Participant &&
            identity == other.identity &&
            user == other.user &&
            admissionState == other.admissionState &&
            admissionVersion == other.admissionVersion &&
            requestId == other.requestId &&
            attemptId == other.attemptId &&
            attemptVersion == other.attemptVersion &&
            status == other.status &&
            requestedAt == other.requestedAt &&
            expiresAt == other.expiresAt &&
            approvedAt == other.approvedAt &&
            activatedAt == other.activatedAt &&
            connectedAt == other.connectedAt &&
            connected == other.connected &&
            connectionState == other.connectionState &&
            eligible == other.eligible &&
            returning == other.returning &&
            sessionStarted == other.sessionStarted &&
            lateArrival == other.lateArrival &&
            permissionStatus == other.permissionStatus &&
            permissionRevision == other.permissionRevision &&
            appliedPermissionRevision == other.appliedPermissionRevision &&
            lastError == other.lastError &&
            nextRetryAt == other.nextRetryAt &&
            decisionActor == other.decisionActor &&
            admissionBlockReason == other.admissionBlockReason;
  }

  @override
  int get hashCode {
    return Object.hashAll([
      identity,
      user,
      admissionState,
      admissionVersion,
      requestId,
      attemptId,
      attemptVersion,
      status,
      requestedAt,
      expiresAt,
      approvedAt,
      activatedAt,
      connectedAt,
      connected,
      connectionState,
      eligible,
      returning,
      sessionStarted,
      lateArrival,
      permissionStatus,
      permissionRevision,
      appliedPermissionRevision,
      lastError,
      nextRetryAt,
      decisionActor,
      admissionBlockReason,
    ]);
  }

  @override
  String toString() {
    return 'Participant(identity: $identity, user: $user, admissionState: $admissionState, admissionVersion: $admissionVersion, requestId: $requestId, attemptId: $attemptId, attemptVersion: $attemptVersion, status: $status, requestedAt: $requestedAt, expiresAt: $expiresAt, approvedAt: $approvedAt, activatedAt: $activatedAt, connectedAt: $connectedAt, connected: $connected, connectionState: $connectionState, eligible: $eligible, returning: $returning, sessionStarted: $sessionStarted, lateArrival: $lateArrival, permissionStatus: $permissionStatus, permissionRevision: $permissionRevision, appliedPermissionRevision: $appliedPermissionRevision, lastError: $lastError, nextRetryAt: $nextRetryAt, decisionActor: $decisionActor, admissionBlockReason: $admissionBlockReason)';
  }
}
