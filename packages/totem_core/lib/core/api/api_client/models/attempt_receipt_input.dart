// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:degenerate_runtime/degenerate_runtime.dart';

@immutable
final class AttemptReceiptInput {
  const AttemptReceiptInput({
    required this.requestId,
    required this.attemptId,
    required this.expectedVersion,
  });

  factory AttemptReceiptInput.fromJson(Map<String, dynamic> json) {
    return AttemptReceiptInput(
      requestId: json['request_id'] as String,
      attemptId: json['attempt_id'] as String,
      expectedVersion: (json['expected_version'] as num).toInt(),
    );
  }

  final String requestId;

  final String attemptId;

  final int expectedVersion;

  Map<String, dynamic> toJson() {
    return {
      'request_id': requestId,
      'attempt_id': attemptId,
      'expected_version': expectedVersion,
    };
  }

  static bool canParse(Map<String, dynamic> json) {
    return json.containsKey('request_id') &&
        json['request_id'] is String &&
        json.containsKey('attempt_id') &&
        json['attempt_id'] is String &&
        json.containsKey('expected_version') &&
        json['expected_version'] is num;
  }

  AttemptReceiptInput copyWith({
    String? requestId,
    String? attemptId,
    int? expectedVersion,
  }) {
    return AttemptReceiptInput(
      requestId: requestId ?? this.requestId,
      attemptId: attemptId ?? this.attemptId,
      expectedVersion: expectedVersion ?? this.expectedVersion,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AttemptReceiptInput &&
            requestId == other.requestId &&
            attemptId == other.attemptId &&
            expectedVersion == other.expectedVersion;
  }

  @override
  int get hashCode {
    return Object.hash(requestId, attemptId, expectedVersion);
  }

  @override
  String toString() {
    return 'AttemptReceiptInput(requestId: $requestId, attemptId: $attemptId, expectedVersion: $expectedVersion)';
  }
}
