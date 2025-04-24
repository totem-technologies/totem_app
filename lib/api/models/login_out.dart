// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import

import 'package:json_annotation/json_annotation.dart';

part 'login_out.g.dart';

@JsonSerializable()
class LoginOut {
  const LoginOut({required this.login});

  factory LoginOut.fromJson(Map<String, Object?> json) =>
      _$LoginOutFromJson(json);

  final bool login;

  Map<String, Object?> toJson() => _$LoginOutToJson(this);
}
