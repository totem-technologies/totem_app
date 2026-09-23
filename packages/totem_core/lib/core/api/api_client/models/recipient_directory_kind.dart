// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:degenerate_runtime/degenerate_runtime.dart';

@immutable
final class RecipientDirectoryKind {
  const RecipientDirectoryKind._(this.value);

  factory RecipientDirectoryKind.fromJson(String json) {
    return switch (json) {
      'keepers' => keepers,
      'participants' => participants,
      _ => RecipientDirectoryKind._(json),
    };
  }

  static const RecipientDirectoryKind keepers = RecipientDirectoryKind._(
    'keepers',
  );

  static const RecipientDirectoryKind participants = RecipientDirectoryKind._(
    'participants',
  );

  static const List<RecipientDirectoryKind> values = [keepers, participants];

  final String value;

  String toJson() {
    return value;
  }

  /// Whether this value is unknown (not defined in the OpenAPI spec).
  bool get isUnknown {
    return !values.contains(this);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is RecipientDirectoryKind && other.value == value;
  }

  @override
  int get hashCode {
    return value.hashCode;
  }

  @override
  String toString() {
    return 'RecipientDirectoryKind($value)';
  }
}
