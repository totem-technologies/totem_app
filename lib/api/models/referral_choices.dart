// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import

import 'package:json_annotation/json_annotation.dart';

@JsonEnum()
enum ReferralChoices {
  /// The name has been replaced because it contains a keyword. Original name: `default`.
  @JsonValue('default')
  valueDefault('default'),
  @JsonValue('search')
  search('search'),
  @JsonValue('social')
  social('social'),
  @JsonValue('keeper')
  keeper('keeper'),
  @JsonValue('pamphlet')
  pamphlet('pamphlet'),
  @JsonValue('blog')
  blog('blog'),
  @JsonValue('newsletter')
  newsletter('newsletter'),
  @JsonValue('dream')
  dream('dream'),
  @JsonValue('other')
  other('other'),

  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const ReferralChoices(this.json);

  factory ReferralChoices.fromJson(String json) => values.firstWhere(
    (e) => e.json == json,
    orElse: () => $unknown,
  );

  final String? json;

  @override
  String toString() => json ?? super.toString();

  /// Returns all defined enum values excluding the $unknown value.
  static List<ReferralChoices> get $valuesDefined =>
      values.where((value) => value != $unknown).toList();
}
