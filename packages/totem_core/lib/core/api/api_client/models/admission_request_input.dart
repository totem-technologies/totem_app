// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:degenerate_runtime/degenerate_runtime.dart';

@immutable
final class AdmissionRequestInput {
  const AdmissionRequestInput({
    required this.requestId,
    required this.attemptId,
    this.connected,
  });

  factory AdmissionRequestInput.fromJson(Map<String, dynamic> json) {
    return AdmissionRequestInput(
      requestId: json['request_id'] as String,
      attemptId: json['attempt_id'] as String,
      connected: json['connected'] as bool?,
    );
  }

  final String requestId;

  final String attemptId;

  final bool? connected;

  /// The value with the schema default applied when absent.
  bool get connectedOrDefault {
    return connected ?? false;
  }

  Map<String, dynamic> toJson() {
    return {
      'request_id': requestId,
      'attempt_id': attemptId,
      'connected': ?connected,
    };
  }

  static bool canParse(Map<String, dynamic> json) {
    return json.containsKey('request_id') &&
        json['request_id'] is String &&
        json.containsKey('attempt_id') &&
        json['attempt_id'] is String;
  }

  AdmissionRequestInput copyWith({
    String? requestId,
    String? attemptId,
    bool? Function()? connected,
  }) {
    return AdmissionRequestInput(
      requestId: requestId ?? this.requestId,
      attemptId: attemptId ?? this.attemptId,
      connected: connected != null ? connected() : this.connected,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AdmissionRequestInput &&
            requestId == other.requestId &&
            attemptId == other.attemptId &&
            connected == other.connected;
  }

  @override
  int get hashCode {
    return Object.hash(requestId, attemptId, connected);
  }

  @override
  String toString() {
    return 'AdmissionRequestInput(requestId: $requestId, attemptId: $attemptId, connected: $connected)';
  }
}
