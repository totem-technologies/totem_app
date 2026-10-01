// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:degenerate_runtime/degenerate_runtime.dart';
import 'session_prompt_schema.dart';

@immutable
final class SessionPromptsStaleRevisionSchema {
  const SessionPromptsStaleRevisionSchema({
    required this.revision,
    required this.prompts,
    this.code,
    this.message,
  });

  factory SessionPromptsStaleRevisionSchema.fromJson(
    Map<String, dynamic> json,
  ) {
    return SessionPromptsStaleRevisionSchema(
      revision: (json['revision'] as num).toInt(),
      prompts: (json['prompts'] as List<dynamic>)
          .map((e) => SessionPromptSchema.fromJson(e as Map<String, dynamic>))
          .toList(),
      code: json['code'] as String?,
      message: json['message'] as String?,
    );
  }

  final int revision;

  final List<SessionPromptSchema> prompts;

  final String? code;

  final String? message;

  /// The value with the schema default applied when absent.
  String get codeOrDefault {
    return code ?? 'stale_prompt_revision';
  }

  /// The value with the schema default applied when absent.
  String get messageOrDefault {
    return message ??
        'Prepared prompts have changed. Re-fetch them and try again.';
  }

  Map<String, dynamic> toJson() {
    return {
      'revision': revision,
      'prompts': prompts.map((e) => e.toJson()).toList(),
      'code': ?code,
      'message': ?message,
    };
  }

  static bool canParse(Map<String, dynamic> json) {
    return json.containsKey('revision') &&
        json['revision'] is num &&
        json.containsKey('prompts');
  }

  SessionPromptsStaleRevisionSchema copyWith({
    int? revision,
    List<SessionPromptSchema>? prompts,
    String? Function()? code,
    String? Function()? message,
  }) {
    return SessionPromptsStaleRevisionSchema(
      revision: revision ?? this.revision,
      prompts: prompts ?? this.prompts,
      code: code != null ? code() : this.code,
      message: message != null ? message() : this.message,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SessionPromptsStaleRevisionSchema &&
            revision == other.revision &&
            listEquals(prompts, other.prompts) &&
            code == other.code &&
            message == other.message;
  }

  @override
  int get hashCode {
    return Object.hash(revision, Object.hashAll(prompts), code, message);
  }

  @override
  String toString() {
    return 'SessionPromptsStaleRevisionSchema(revision: $revision, prompts: $prompts, code: $code, message: $message)';
  }
}
