// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:degenerate_runtime/degenerate_runtime.dart';

@immutable
final class ReadinessReason {
  const ReadinessReason._(this.value);

  factory ReadinessReason.fromJson(String json) {
    return switch (json) {
      'session_ended' => sessionEnded,
      'not_eligible' => notEligible,
      'no_request' => noRequest,
      'request_expired' => requestExpired,
      'request_declined' => requestDeclined,
      'request_permanently_declined' => requestPermanentlyDeclined,
      'request_cancelled' => requestCancelled,
      'request_superseded' => requestSuperseded,
      'request_revoked' => requestRevoked,
      'request_failed' => requestFailed,
      'invalid_request' => invalidRequest,
      'requires_reapproval' => requiresReapproval,
      'permanently_declined' => permanentlyDeclined,
      'not_admitted' => notAdmitted,
      'admission_full' => admissionFull,
      'approval_required' => approvalRequired,
      'connection_required' => connectionRequired,
      'permission_pending' => permissionPending,
      'connection_changed' => connectionChanged,
      _ => ReadinessReason._(json),
    };
  }

  static const ReadinessReason sessionEnded = ReadinessReason._(
    'session_ended',
  );

  static const ReadinessReason notEligible = ReadinessReason._('not_eligible');

  static const ReadinessReason noRequest = ReadinessReason._('no_request');

  static const ReadinessReason requestExpired = ReadinessReason._(
    'request_expired',
  );

  static const ReadinessReason requestDeclined = ReadinessReason._(
    'request_declined',
  );

  static const ReadinessReason requestPermanentlyDeclined = ReadinessReason._(
    'request_permanently_declined',
  );

  static const ReadinessReason requestCancelled = ReadinessReason._(
    'request_cancelled',
  );

  static const ReadinessReason requestSuperseded = ReadinessReason._(
    'request_superseded',
  );

  static const ReadinessReason requestRevoked = ReadinessReason._(
    'request_revoked',
  );

  static const ReadinessReason requestFailed = ReadinessReason._(
    'request_failed',
  );

  static const ReadinessReason invalidRequest = ReadinessReason._(
    'invalid_request',
  );

  static const ReadinessReason requiresReapproval = ReadinessReason._(
    'requires_reapproval',
  );

  static const ReadinessReason permanentlyDeclined = ReadinessReason._(
    'permanently_declined',
  );

  static const ReadinessReason notAdmitted = ReadinessReason._('not_admitted');

  static const ReadinessReason admissionFull = ReadinessReason._(
    'admission_full',
  );

  static const ReadinessReason approvalRequired = ReadinessReason._(
    'approval_required',
  );

  static const ReadinessReason connectionRequired = ReadinessReason._(
    'connection_required',
  );

  static const ReadinessReason permissionPending = ReadinessReason._(
    'permission_pending',
  );

  static const ReadinessReason connectionChanged = ReadinessReason._(
    'connection_changed',
  );

  static const List<ReadinessReason> values = [
    sessionEnded,
    notEligible,
    noRequest,
    requestExpired,
    requestDeclined,
    requestPermanentlyDeclined,
    requestCancelled,
    requestSuperseded,
    requestRevoked,
    requestFailed,
    invalidRequest,
    requiresReapproval,
    permanentlyDeclined,
    notAdmitted,
    admissionFull,
    approvalRequired,
    connectionRequired,
    permissionPending,
    connectionChanged,
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
        other is ReadinessReason && other.value == value;
  }

  @override
  int get hashCode {
    return value.hashCode;
  }

  @override
  String toString() {
    return 'ReadinessReason($value)';
  }
}

@immutable
final class ReadinessState {
  const ReadinessState._(this.value);

  factory ReadinessState.fromJson(String json) {
    return switch (json) {
      'waiting_for_approval' => waitingForApproval,
      'applying_permissions' => applyingPermissions,
      'ready_to_activate' => readyToActivate,
      'activated' => activated,
      'blocked' => blocked,
      'ended' => ended,
      'requires_new_attempt' => requiresNewAttempt,
      _ => ReadinessState._(json),
    };
  }

  static const ReadinessState waitingForApproval = ReadinessState._(
    'waiting_for_approval',
  );

  static const ReadinessState applyingPermissions = ReadinessState._(
    'applying_permissions',
  );

  static const ReadinessState readyToActivate = ReadinessState._(
    'ready_to_activate',
  );

  static const ReadinessState activated = ReadinessState._('activated');

  static const ReadinessState blocked = ReadinessState._('blocked');

  static const ReadinessState ended = ReadinessState._('ended');

  static const ReadinessState requiresNewAttempt = ReadinessState._(
    'requires_new_attempt',
  );

  static const List<ReadinessState> values = [
    waitingForApproval,
    applyingPermissions,
    readyToActivate,
    activated,
    blocked,
    ended,
    requiresNewAttempt,
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
        other is ReadinessState && other.value == value;
  }

  @override
  int get hashCode {
    return value.hashCode;
  }

  @override
  String toString() {
    return 'ReadinessState($value)';
  }
}

@immutable
final class AdmissionReadiness {
  const AdmissionReadiness({
    required this.state,
    this.reason = const Omittable.absent(),
  });

  factory AdmissionReadiness.fromJson(Map<String, dynamic> json) {
    return AdmissionReadiness(
      state: ReadinessState.fromJson(json['state'] as String),
      reason: json.containsKey('reason')
          ? Omittable(
              json['reason'] != null
                  ? ReadinessReason.fromJson(json['reason'] as String)
                  : null,
            )
          : const Omittable.absent(),
    );
  }

  final ReadinessState state;

  final Omittable<ReadinessReason?> reason;

  Map<String, dynamic> toJson() {
    return {
      'state': state.toJson(),
      if (reason.isPresent) 'reason': reason.value?.toJson(),
    };
  }

  static bool canParse(Map<String, dynamic> json) {
    return json.containsKey('state');
  }

  AdmissionReadiness copyWith({
    ReadinessState? state,
    Omittable<ReadinessReason?>? reason,
  }) {
    return AdmissionReadiness(
      state: state ?? this.state,
      reason: reason ?? this.reason,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AdmissionReadiness &&
            state == other.state &&
            reason == other.reason;
  }

  @override
  int get hashCode {
    return Object.hash(state, reason);
  }

  @override
  String toString() {
    return 'AdmissionReadiness(state: $state, reason: $reason)';
  }
}
