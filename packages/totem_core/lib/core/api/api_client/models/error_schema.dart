// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:degenerate_runtime/degenerate_runtime.dart';

@immutable
final class ErrorSchema {
  const ErrorSchema({
    required this.code,
    required this.message,
    this.detail = const Omittable.absent(),
  });

  factory ErrorSchema.fromJson(Map<String, dynamic> json) {
    return ErrorSchema(
      code: json['code'] as String,
      message: json['message'] as String,
      detail: json.containsKey('detail')
          ? Omittable(json['detail'] as String?)
          : const Omittable.absent(),
    );
  }

  final String code;

  final String message;

  final Omittable<String?> detail;

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'message': message,
      if (detail.isPresent) 'detail': detail.value,
    };
  }

  static bool canParse(Map<String, dynamic> json) {
    return json.containsKey('code') &&
        json['code'] is String &&
        json.containsKey('message') &&
        json['message'] is String;
  }

  ErrorSchema copyWith({
    String? code,
    String? message,
    Omittable<String?>? detail,
  }) {
    return ErrorSchema(
      code: code ?? this.code,
      message: message ?? this.message,
      detail: detail ?? this.detail,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ErrorSchema &&
            code == other.code &&
            message == other.message &&
            detail == other.detail;
  }

  @override
  int get hashCode {
    return Object.hash(code, message, detail);
  }

  @override
  String toString() {
    return 'ErrorSchema(code: $code, message: $message, detail: $detail)';
  }
}
