// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:degenerate_runtime/degenerate_runtime.dart';

import 'participant.dart';

@immutable
final class CommandResultOutcome {
  const CommandResultOutcome._(this.value);

  factory CommandResultOutcome.fromJson(String json) {
    return switch (json) {
      'approved' => approved,
      'declined' => declined,
      'permanently_declined' => permanentlyDeclined,
      'allowed' => allowed,
      'revoked' => revoked,
      'skipped' => skipped,
      _ => CommandResultOutcome._(json),
    };
  }

  static const CommandResultOutcome approved = CommandResultOutcome._(
    'approved',
  );

  static const CommandResultOutcome declined = CommandResultOutcome._(
    'declined',
  );

  static const CommandResultOutcome permanentlyDeclined =
      CommandResultOutcome._('permanently_declined');

  static const CommandResultOutcome allowed = CommandResultOutcome._('allowed');

  static const CommandResultOutcome revoked = CommandResultOutcome._('revoked');

  static const CommandResultOutcome skipped = CommandResultOutcome._('skipped');

  static const List<CommandResultOutcome> values = [
    approved,
    declined,
    permanentlyDeclined,
    allowed,
    revoked,
    skipped,
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
        other is CommandResultOutcome && other.value == value;
  }

  @override
  int get hashCode {
    return value.hashCode;
  }

  @override
  String toString() {
    return 'CommandResultOutcome($value)';
  }
}

@immutable
final class CommandResultError {
  const CommandResultError._(this.value);

  factory CommandResultError.fromJson(String json) {
    return switch (json) {
      'not_keeper' => notKeeper,
      'not_eligible' => notEligible,
      'permanently_declined' => permanentlyDeclined,
      'ended' => ended,
      'not_found' => notFound,
      'feature_disabled' => featureDisabled,
      'stale_version' => staleVersion,
      'invalid_attempt' => invalidAttempt,
      'permission_pending' => permissionPending,
      'connection_required' => connectionRequired,
      'command_conflict' => commandConflict,
      'admission_full' => admissionFull,
      'waiting_full' => waitingFull,
      'room_full' => roomFull,
      'presence_unavailable' => presenceUnavailable,
      'room_missing' => roomMissing,
      'participant_missing' => participantMissing,
      'missing' => missing,
      'disconnected' => disconnected,
      'identity_replaced' => identityReplaced,
      'permission_mismatch' => permissionMismatch,
      'unavailable' => unavailable,
      'timeout' => timeout,
      'requires_reapproval' => requiresReapproval,
      'approval_required' => approvalRequired,
      _ => CommandResultError._(json),
    };
  }

  static const CommandResultError notKeeper = CommandResultError._(
    'not_keeper',
  );

  static const CommandResultError notEligible = CommandResultError._(
    'not_eligible',
  );

  static const CommandResultError permanentlyDeclined = CommandResultError._(
    'permanently_declined',
  );

  static const CommandResultError ended = CommandResultError._('ended');

  static const CommandResultError notFound = CommandResultError._('not_found');

  static const CommandResultError featureDisabled = CommandResultError._(
    'feature_disabled',
  );

  static const CommandResultError staleVersion = CommandResultError._(
    'stale_version',
  );

  static const CommandResultError invalidAttempt = CommandResultError._(
    'invalid_attempt',
  );

  static const CommandResultError permissionPending = CommandResultError._(
    'permission_pending',
  );

  static const CommandResultError connectionRequired = CommandResultError._(
    'connection_required',
  );

  static const CommandResultError commandConflict = CommandResultError._(
    'command_conflict',
  );

  static const CommandResultError admissionFull = CommandResultError._(
    'admission_full',
  );

  static const CommandResultError waitingFull = CommandResultError._(
    'waiting_full',
  );

  static const CommandResultError roomFull = CommandResultError._('room_full');

  static const CommandResultError presenceUnavailable = CommandResultError._(
    'presence_unavailable',
  );

  static const CommandResultError roomMissing = CommandResultError._(
    'room_missing',
  );

  static const CommandResultError participantMissing = CommandResultError._(
    'participant_missing',
  );

  static const CommandResultError missing = CommandResultError._('missing');

  static const CommandResultError disconnected = CommandResultError._(
    'disconnected',
  );

  static const CommandResultError identityReplaced = CommandResultError._(
    'identity_replaced',
  );

  static const CommandResultError permissionMismatch = CommandResultError._(
    'permission_mismatch',
  );

  static const CommandResultError unavailable = CommandResultError._(
    'unavailable',
  );

  static const CommandResultError timeout = CommandResultError._('timeout');

  static const CommandResultError requiresReapproval = CommandResultError._(
    'requires_reapproval',
  );

  static const CommandResultError approvalRequired = CommandResultError._(
    'approval_required',
  );

  static const List<CommandResultError> values = [
    notKeeper,
    notEligible,
    permanentlyDeclined,
    ended,
    notFound,
    featureDisabled,
    staleVersion,
    invalidAttempt,
    permissionPending,
    connectionRequired,
    commandConflict,
    admissionFull,
    waitingFull,
    roomFull,
    presenceUnavailable,
    roomMissing,
    participantMissing,
    missing,
    disconnected,
    identityReplaced,
    permissionMismatch,
    unavailable,
    timeout,
    requiresReapproval,
    approvalRequired,
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
        other is CommandResultError && other.value == value;
  }

  @override
  int get hashCode {
    return value.hashCode;
  }

  @override
  String toString() {
    return 'CommandResultError($value)';
  }
}

@immutable
final class CommandResult {
  const CommandResult({
    required this.outcome,
    this.identity = const Omittable.absent(),
    this.requestId = const Omittable.absent(),
    this.attemptId = const Omittable.absent(),
    this.error = const Omittable.absent(),
    this.participant = const Omittable.absent(),
  });

  factory CommandResult.fromJson(Map<String, dynamic> json) {
    return CommandResult(
      identity: json.containsKey('identity')
          ? Omittable(json['identity'] as String?)
          : const Omittable.absent(),
      requestId: json.containsKey('request_id')
          ? Omittable(json['request_id'] as String?)
          : const Omittable.absent(),
      attemptId: json.containsKey('attempt_id')
          ? Omittable(json['attempt_id'] as String?)
          : const Omittable.absent(),
      outcome: CommandResultOutcome.fromJson(json['outcome'] as String),
      error: json.containsKey('error')
          ? Omittable(
              json['error'] != null
                  ? CommandResultError.fromJson(json['error'] as String)
                  : null,
            )
          : const Omittable.absent(),
      participant: json.containsKey('participant')
          ? Omittable(
              json['participant'] != null
                  ? Participant.fromJson(
                      json['participant'] as Map<String, dynamic>,
                    )
                  : null,
            )
          : const Omittable.absent(),
    );
  }

  final Omittable<String?> identity;

  final Omittable<String?> requestId;

  final Omittable<String?> attemptId;

  final CommandResultOutcome outcome;

  final Omittable<CommandResultError?> error;

  final Omittable<Participant?> participant;

  Map<String, dynamic> toJson() {
    return {
      if (identity.isPresent) 'identity': identity.value,
      if (requestId.isPresent) 'request_id': requestId.value,
      if (attemptId.isPresent) 'attempt_id': attemptId.value,
      'outcome': outcome.toJson(),
      if (error.isPresent) 'error': error.value?.toJson(),
      if (participant.isPresent) 'participant': participant.value?.toJson(),
    };
  }

  static bool canParse(Map<String, dynamic> json) {
    return json.containsKey('outcome');
  }

  CommandResult copyWith({
    Omittable<String?>? identity,
    Omittable<String?>? requestId,
    Omittable<String?>? attemptId,
    CommandResultOutcome? outcome,
    Omittable<CommandResultError?>? error,
    Omittable<Participant?>? participant,
  }) {
    return CommandResult(
      identity: identity ?? this.identity,
      requestId: requestId ?? this.requestId,
      attemptId: attemptId ?? this.attemptId,
      outcome: outcome ?? this.outcome,
      error: error ?? this.error,
      participant: participant ?? this.participant,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CommandResult &&
            identity == other.identity &&
            requestId == other.requestId &&
            attemptId == other.attemptId &&
            outcome == other.outcome &&
            error == other.error &&
            participant == other.participant;
  }

  @override
  int get hashCode {
    return Object.hash(
      identity,
      requestId,
      attemptId,
      outcome,
      error,
      participant,
    );
  }

  @override
  String toString() {
    return 'CommandResult(identity: $identity, requestId: $requestId, attemptId: $attemptId, outcome: $outcome, error: $error, participant: $participant)';
  }
}
