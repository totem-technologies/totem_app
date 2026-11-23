// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:degenerate_runtime/degenerate_runtime.dart';

@immutable
final class ErrorSchemaCode {
  const ErrorSchemaCode._(this.value);

  factory ErrorSchemaCode.fromJson(String json) {
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
      _ => ErrorSchemaCode._(json),
    };
  }

  static const ErrorSchemaCode notKeeper = ErrorSchemaCode._('not_keeper');

  static const ErrorSchemaCode notEligible = ErrorSchemaCode._('not_eligible');

  static const ErrorSchemaCode permanentlyDeclined = ErrorSchemaCode._(
    'permanently_declined',
  );

  static const ErrorSchemaCode ended = ErrorSchemaCode._('ended');

  static const ErrorSchemaCode notFound = ErrorSchemaCode._('not_found');

  static const ErrorSchemaCode featureDisabled = ErrorSchemaCode._(
    'feature_disabled',
  );

  static const ErrorSchemaCode staleVersion = ErrorSchemaCode._(
    'stale_version',
  );

  static const ErrorSchemaCode invalidAttempt = ErrorSchemaCode._(
    'invalid_attempt',
  );

  static const ErrorSchemaCode permissionPending = ErrorSchemaCode._(
    'permission_pending',
  );

  static const ErrorSchemaCode connectionRequired = ErrorSchemaCode._(
    'connection_required',
  );

  static const ErrorSchemaCode commandConflict = ErrorSchemaCode._(
    'command_conflict',
  );

  static const ErrorSchemaCode admissionFull = ErrorSchemaCode._(
    'admission_full',
  );

  static const ErrorSchemaCode waitingFull = ErrorSchemaCode._('waiting_full');

  static const ErrorSchemaCode roomFull = ErrorSchemaCode._('room_full');

  static const ErrorSchemaCode presenceUnavailable = ErrorSchemaCode._(
    'presence_unavailable',
  );

  static const ErrorSchemaCode roomMissing = ErrorSchemaCode._('room_missing');

  static const ErrorSchemaCode participantMissing = ErrorSchemaCode._(
    'participant_missing',
  );

  static const ErrorSchemaCode missing = ErrorSchemaCode._('missing');

  static const ErrorSchemaCode disconnected = ErrorSchemaCode._('disconnected');

  static const ErrorSchemaCode identityReplaced = ErrorSchemaCode._(
    'identity_replaced',
  );

  static const ErrorSchemaCode permissionMismatch = ErrorSchemaCode._(
    'permission_mismatch',
  );

  static const ErrorSchemaCode unavailable = ErrorSchemaCode._('unavailable');

  static const ErrorSchemaCode timeout = ErrorSchemaCode._('timeout');

  static const List<ErrorSchemaCode> values = [
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
        other is ErrorSchemaCode && other.value == value;
  }

  @override
  int get hashCode {
    return value.hashCode;
  }

  @override
  String toString() {
    return 'ErrorSchemaCode($value)';
  }
}

@immutable
final class ErrorSchema {
  const ErrorSchema({
    required this.code,
    required this.message,
    this.detail = const Omittable.absent(),
  });

  factory ErrorSchema.fromJson(Map<String, dynamic> json) {
    return ErrorSchema(
      code: ErrorSchemaCode.fromJson(json['code'] as String),
      message: json['message'] as String,
      detail: json.containsKey('detail')
          ? Omittable(json['detail'] as String?)
          : const Omittable.absent(),
    );
  }

  final ErrorSchemaCode code;

  final String message;

  final Omittable<String?> detail;

  Map<String, dynamic> toJson() {
    return {
      'code': code.toJson(),
      'message': message,
      if (detail.isPresent) 'detail': detail.value,
    };
  }

  static bool canParse(Map<String, dynamic> json) {
    return json.containsKey('code') &&
        json.containsKey('message') &&
        json['message'] is String;
  }

  ErrorSchema copyWith({
    ErrorSchemaCode? code,
    String? message,
    Omittable<String?>? detail,
  }) {
    return ErrorSchema(
      code: code ?? this.code,
      message: message ?? this.message,
      detail: detail ?? this.detail,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ErrorSchema &&
            code == other.code &&
            message == other.message &&
            detail == other.detail;
  }

  @override
  int get hashCode {
    return Object.hash(code, message, detail);
  }

  @override
  String toString() {
    return 'ErrorSchema(code: $code, message: $message, detail: $detail)';
  }
}
