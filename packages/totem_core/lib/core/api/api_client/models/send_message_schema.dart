// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:degenerate_runtime/degenerate_runtime.dart';

@immutable
final class SendMessageSchema {
  const SendMessageSchema({required this.text, this.clientMessageId});

  factory SendMessageSchema.fromJson(Map<String, dynamic> json) {
    return SendMessageSchema(
      text: json['text'] as String,
      clientMessageId: json['client_message_id'] as String?,
    );
  }

  final String text;

  final String? clientMessageId;

  Map<String, dynamic> toJson() {
    return {'text': text, 'client_message_id': ?clientMessageId};
  }

  static bool canParse(Map<String, dynamic> json) {
    return json.containsKey('text') && json['text'] is String;
  }

  SendMessageSchema copyWith({
    String? text,
    String? Function()? clientMessageId,
  }) {
    return SendMessageSchema(
      text: text ?? this.text,
      clientMessageId: clientMessageId != null
          ? clientMessageId()
          : this.clientMessageId,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SendMessageSchema &&
            text == other.text &&
            clientMessageId == other.clientMessageId;
  }

  @override
  int get hashCode {
    return Object.hash(text, clientMessageId);
  }

  @override
  String toString() {
    return 'SendMessageSchema(text: $text, clientMessageId: $clientMessageId)';
  }
}
