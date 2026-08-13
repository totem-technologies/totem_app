// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:degenerate_runtime/degenerate_runtime.dart';

@immutable
final class SwitchSessionSchema {
  const SwitchSessionSchema({required this.conflictingSessionSlug});

  factory SwitchSessionSchema.fromJson(Map<String, dynamic> json) {
    return SwitchSessionSchema(
      conflictingSessionSlug: json['conflicting_session_slug'] as String,
    );
  }

  final String conflictingSessionSlug;

  Map<String, dynamic> toJson() {
    return {
      'conflicting_session_slug': conflictingSessionSlug,
    };
  }

  static bool canParse(Map<String, dynamic> json) {
    return json.containsKey('conflicting_session_slug') &&
        json['conflicting_session_slug'] is String;
  }

  SwitchSessionSchema copyWith({String? conflictingSessionSlug}) {
    return SwitchSessionSchema(
      conflictingSessionSlug:
          conflictingSessionSlug ?? this.conflictingSessionSlug,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SwitchSessionSchema &&
            conflictingSessionSlug == other.conflictingSessionSlug;
  }

  @override
  int get hashCode {
    return conflictingSessionSlug.hashCode;
  }

  @override
  String toString() {
    return 'SwitchSessionSchema(conflictingSessionSlug: $conflictingSessionSlug)';
  }
}
