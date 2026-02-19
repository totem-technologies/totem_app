// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

@JsonEnum()
enum TurnState {
  @JsonValue('idle')
  idle('idle'),
  @JsonValue('speaking')
  speaking('speaking'),
  @JsonValue('passing')
  passing('passing'),

  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const TurnState(this.json);

  factory TurnState.fromJson(String json) => values.firstWhere(
    (e) => e.json == json,
    orElse: () => $unknown,
  );

  final String? json;

  @override
  String toString() => json?.toString() ?? super.toString();

  /// Returns all defined enum values excluding the $unknown value.
  static List<TurnState> get $valuesDefined =>
      values.where((value) => value != $unknown).toList();
}
