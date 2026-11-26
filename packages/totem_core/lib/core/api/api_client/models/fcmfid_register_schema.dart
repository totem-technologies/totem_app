// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:degenerate_runtime/degenerate_runtime.dart';

@immutable
final class FcmfidRegisterSchema {
  const FcmfidRegisterSchema({required this.fid});

  factory FcmfidRegisterSchema.fromJson(Map<String, dynamic> json) {
    return FcmfidRegisterSchema(fid: json['fid'] as String);
  }

  final String fid;

  Map<String, dynamic> toJson() {
    return {'fid': fid};
  }

  static bool canParse(Map<String, dynamic> json) {
    return json.containsKey('fid') && json['fid'] is String;
  }

  FcmfidRegisterSchema copyWith({String? fid}) {
    return FcmfidRegisterSchema(fid: fid ?? this.fid);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is FcmfidRegisterSchema && fid == other.fid;
  }

  @override
  int get hashCode {
    return fid.hashCode;
  }

  @override
  String toString() {
    return 'FcmfidRegisterSchema(fid: $fid)';
  }
}
