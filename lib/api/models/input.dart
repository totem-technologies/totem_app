// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import

import 'package:json_annotation/json_annotation.dart';

part 'input.g.dart';

@JsonSerializable()
class Input {
  const Input({
    this.limit = 100,
    this.offset = 0,
  });
  
  factory Input.fromJson(Map<String, Object?> json) => _$InputFromJson(json);
  
  final int limit;
  final int offset;

  Map<String, Object?> toJson() => _$InputToJson(this);
}
