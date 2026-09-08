// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:degenerate_runtime/degenerate_runtime.dart';

@immutable
final class SendSessionMessagesSchema {
  const SendSessionMessagesSchema({
    required this.recipientSlugs,
    required this.text,
    required this.clientRequestId,
  });

  factory SendSessionMessagesSchema.fromJson(Map<String, dynamic> json) {
    return SendSessionMessagesSchema(
      recipientSlugs: (json['recipient_slugs'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      text: json['text'] as String,
      clientRequestId: json['client_request_id'] as String,
    );
  }

  final List<String> recipientSlugs;

  final String text;

  final String clientRequestId;

  Map<String, dynamic> toJson() {
    return {
      'recipient_slugs': recipientSlugs,
      'text': text,
      'client_request_id': clientRequestId,
    };
  }

  static bool canParse(Map<String, dynamic> json) {
    return json.containsKey('recipient_slugs') &&
        json.containsKey('text') &&
        json['text'] is String &&
        json.containsKey('client_request_id') &&
        json['client_request_id'] is String;
  }

  SendSessionMessagesSchema copyWith({
    List<String>? recipientSlugs,
    String? text,
    String? clientRequestId,
  }) {
    return SendSessionMessagesSchema(
      recipientSlugs: recipientSlugs ?? this.recipientSlugs,
      text: text ?? this.text,
      clientRequestId: clientRequestId ?? this.clientRequestId,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SendSessionMessagesSchema &&
            listEquals(recipientSlugs, other.recipientSlugs) &&
            text == other.text &&
            clientRequestId == other.clientRequestId;
  }

  @override
  int get hashCode {
    return Object.hash(Object.hashAll(recipientSlugs), text, clientRequestId);
  }

  @override
  String toString() {
    return 'SendSessionMessagesSchema(recipientSlugs: $recipientSlugs, text: $text, clientRequestId: $clientRequestId)';
  }
}
