// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:degenerate_runtime/degenerate_runtime.dart';

/// An operation resumes an active attempt by default; fresh starts a new one.
///
/// A returning admitted user resumes when connected, otherwise starts a new
/// attempt. Retry with the same operation ID and fresh value. Alternatively
/// supply both legacy request/attempt IDs. The response contains canonical IDs.
@immutable
final class JoinRoomRequest {
  const JoinRoomRequest({
    this.operationId = const Omittable.absent(),
    this.fresh,
    this.requestId = const Omittable.absent(),
    this.attemptId = const Omittable.absent(),
  });

  factory JoinRoomRequest.fromJson(Map<String, dynamic> json) {
    return JoinRoomRequest(
      operationId: json.containsKey('operation_id')
          ? Omittable(json['operation_id'] as String?)
          : const Omittable.absent(),
      fresh: json['fresh'] as bool?,
      requestId: json.containsKey('request_id')
          ? Omittable(json['request_id'] as String?)
          : const Omittable.absent(),
      attemptId: json.containsKey('attempt_id')
          ? Omittable(json['attempt_id'] as String?)
          : const Omittable.absent(),
    );
  }

  final Omittable<String?> operationId;

  final bool? fresh;

  final Omittable<String?> requestId;

  final Omittable<String?> attemptId;

  /// The value with the schema default applied when absent.
  bool get freshOrDefault {
    return fresh ?? false;
  }

  Map<String, dynamic> toJson() {
    return {
      if (operationId.isPresent) 'operation_id': operationId.value,
      'fresh': ?fresh,
      if (requestId.isPresent) 'request_id': requestId.value,
      if (attemptId.isPresent) 'attempt_id': attemptId.value,
    };
  }

  static bool canParse(Map<String, dynamic> json) {
    return json.keys.any(
      (key) => const {
        'operation_id',
        'fresh',
        'request_id',
        'attempt_id',
      }.contains(key),
    );
  }

  JoinRoomRequest copyWith({
    Omittable<String?>? operationId,
    bool? Function()? fresh,
    Omittable<String?>? requestId,
    Omittable<String?>? attemptId,
  }) {
    return JoinRoomRequest(
      operationId: operationId ?? this.operationId,
      fresh: fresh != null ? fresh() : this.fresh,
      requestId: requestId ?? this.requestId,
      attemptId: attemptId ?? this.attemptId,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is JoinRoomRequest &&
            operationId == other.operationId &&
            fresh == other.fresh &&
            requestId == other.requestId &&
            attemptId == other.attemptId;
  }

  @override
  int get hashCode {
    return Object.hash(operationId, fresh, requestId, attemptId);
  }

  @override
  String toString() {
    return 'JoinRoomRequest(operationId: $operationId, fresh: $fresh, requestId: $requestId, attemptId: $attemptId)';
  }
}
