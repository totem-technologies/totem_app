// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:degenerate_runtime/degenerate_runtime.dart';
import 'participant.dart';

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
      outcome: json['outcome'] as String,
      error: json.containsKey('error')
          ? Omittable(json['error'] as String?)
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

  final String outcome;

  final Omittable<String?> error;

  final Omittable<Participant?> participant;

  Map<String, dynamic> toJson() {
    return {
      if (identity.isPresent) 'identity': identity.value,
      if (requestId.isPresent) 'request_id': requestId.value,
      if (attemptId.isPresent) 'attempt_id': attemptId.value,
      'outcome': outcome,
      if (error.isPresent) 'error': error.value,
      if (participant.isPresent) 'participant': participant.value?.toJson(),
    };
  }

  static bool canParse(Map<String, dynamic> json) {
    return json.containsKey('outcome') && json['outcome'] is String;
  }

  CommandResult copyWith({
    Omittable<String?>? identity,
    Omittable<String?>? requestId,
    Omittable<String?>? attemptId,
    String? outcome,
    Omittable<String?>? error,
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
