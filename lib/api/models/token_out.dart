// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import

import 'package:json_annotation/json_annotation.dart';

part 'token_out.g.dart';

@JsonSerializable()
class TokenOut {
  const TokenOut({required this.key});

  factory TokenOut.fromJson(Map<String, Object?> json) =>
      _$TokenOutFromJson(json);

  final String key;

  Map<String, Object?> toJson() => _$TokenOutToJson(this);
}
