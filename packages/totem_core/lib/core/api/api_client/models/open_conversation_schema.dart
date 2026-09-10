// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:degenerate_runtime/degenerate_runtime.dart';

@immutable
final class OpenConversationSchema {
  const OpenConversationSchema({required this.recipientSlug});

  factory OpenConversationSchema.fromJson(Map<String, dynamic> json) {
    return OpenConversationSchema(
      recipientSlug: json['recipient_slug'] as String,
    );
  }

  final String recipientSlug;

  Map<String, dynamic> toJson() {
    return {'recipient_slug': recipientSlug};
  }

  static bool canParse(Map<String, dynamic> json) {
    return json.containsKey('recipient_slug') &&
        json['recipient_slug'] is String;
  }

  OpenConversationSchema copyWith({String? recipientSlug}) {
    return OpenConversationSchema(
      recipientSlug: recipientSlug ?? this.recipientSlug,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is OpenConversationSchema && recipientSlug == other.recipientSlug;
  }

  @override
  int get hashCode {
    return recipientSlug.hashCode;
  }

  @override
  String toString() {
    return 'OpenConversationSchema(recipientSlug: $recipientSlug)';
  }
}
