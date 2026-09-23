// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:degenerate_runtime/degenerate_runtime.dart';
import 'session_message_recipient_result_schema.dart';

@immutable
final class SessionMessageResultSchema {
  const SessionMessageResultSchema({
    required this.requestedCount,
    required this.sentCount,
    required this.recipients,
  });

  factory SessionMessageResultSchema.fromJson(Map<String, dynamic> json) {
    return SessionMessageResultSchema(
      requestedCount: (json['requested_count'] as num).toInt(),
      sentCount: (json['sent_count'] as num).toInt(),
      recipients: (json['recipients'] as List<dynamic>)
          .map(
            (e) => SessionMessageRecipientResultSchema.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }

  final int requestedCount;

  final int sentCount;

  final List<SessionMessageRecipientResultSchema> recipients;

  Map<String, dynamic> toJson() {
    return {
      'requested_count': requestedCount,
      'sent_count': sentCount,
      'recipients': recipients.map((e) => e.toJson()).toList(),
    };
  }

  static bool canParse(Map<String, dynamic> json) {
    return json.containsKey('requested_count') &&
        json['requested_count'] is num &&
        json.containsKey('sent_count') &&
        json['sent_count'] is num &&
        json.containsKey('recipients');
  }

  SessionMessageResultSchema copyWith({
    int? requestedCount,
    int? sentCount,
    List<SessionMessageRecipientResultSchema>? recipients,
  }) {
    return SessionMessageResultSchema(
      requestedCount: requestedCount ?? this.requestedCount,
      sentCount: sentCount ?? this.sentCount,
      recipients: recipients ?? this.recipients,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SessionMessageResultSchema &&
            requestedCount == other.requestedCount &&
            sentCount == other.sentCount &&
            listEquals(recipients, other.recipients);
  }

  @override
  int get hashCode {
    return Object.hash(requestedCount, sentCount, Object.hashAll(recipients));
  }

  @override
  String toString() {
    return 'SessionMessageResultSchema(requestedCount: $requestedCount, sentCount: $sentCount, recipients: $recipients)';
  }
}
