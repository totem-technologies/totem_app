// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:degenerate_runtime/degenerate_runtime.dart';

/// Explicit fresh attempts must provide both UUIDs; exact retries are idempotent.
@immutable
final class JoinRoomRequest {
  const JoinRoomRequest({required this.requestId, required this.attemptId});

  factory JoinRoomRequest.fromJson(Map<String, dynamic> json) {
    return JoinRoomRequest(
      requestId: json['request_id'] as String,
      attemptId: json['attempt_id'] as String,
    );
  }

  final String requestId;

  final String attemptId;

  Map<String, dynamic> toJson() {
    return {'request_id': requestId, 'attempt_id': attemptId};
  }

  static bool canParse(Map<String, dynamic> json) {
    return json.containsKey('request_id') &&
        json['request_id'] is String &&
        json.containsKey('attempt_id') &&
        json['attempt_id'] is String;
  }

  JoinRoomRequest copyWith({String? requestId, String? attemptId}) {
    return JoinRoomRequest(
      requestId: requestId ?? this.requestId,
      attemptId: attemptId ?? this.attemptId,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is JoinRoomRequest &&
            requestId == other.requestId &&
            attemptId == other.attemptId;
  }

  @override
  int get hashCode {
    return Object.hash(requestId, attemptId);
  }

  @override
  String toString() {
    return 'JoinRoomRequest(requestId: $requestId, attemptId: $attemptId)';
  }
}
