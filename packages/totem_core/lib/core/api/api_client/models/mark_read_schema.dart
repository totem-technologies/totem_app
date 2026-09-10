// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:degenerate_runtime/degenerate_runtime.dart';

@immutable
final class MarkReadSchema {
  const MarkReadSchema({required this.lastReadMessageId});

  factory MarkReadSchema.fromJson(Map<String, dynamic> json) {
    return MarkReadSchema(
      lastReadMessageId: json['last_read_message_id'] as String,
    );
  }

  final String lastReadMessageId;

  Map<String, dynamic> toJson() {
    return {'last_read_message_id': lastReadMessageId};
  }

  static bool canParse(Map<String, dynamic> json) {
    return json.containsKey('last_read_message_id') &&
        json['last_read_message_id'] is String;
  }

  MarkReadSchema copyWith({String? lastReadMessageId}) {
    return MarkReadSchema(
      lastReadMessageId: lastReadMessageId ?? this.lastReadMessageId,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MarkReadSchema && lastReadMessageId == other.lastReadMessageId;
  }

  @override
  int get hashCode {
    return lastReadMessageId.hashCode;
  }

  @override
  String toString() {
    return 'MarkReadSchema(lastReadMessageId: $lastReadMessageId)';
  }
}
