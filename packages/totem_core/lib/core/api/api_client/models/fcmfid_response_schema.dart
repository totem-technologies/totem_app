// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:degenerate_runtime/degenerate_runtime.dart';

@immutable
final class FcmfidResponseSchema {
  const FcmfidResponseSchema({
    required this.fid,
    required this.active,
    required this.createdAt,
  });

  factory FcmfidResponseSchema.fromJson(Map<String, dynamic> json) {
    return FcmfidResponseSchema(
      fid: json['fid'] as String,
      active: json['active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String fid;

  final bool active;

  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return {
      'fid': fid,
      'active': active,
      'created_at': createdAt.toIso8601String(),
    };
  }

  static bool canParse(Map<String, dynamic> json) {
    return json.containsKey('fid') &&
        json['fid'] is String &&
        json.containsKey('active') &&
        json['active'] is bool &&
        json.containsKey('created_at') &&
        json['created_at'] is String;
  }

  FcmfidResponseSchema copyWith({
    String? fid,
    bool? active,
    DateTime? createdAt,
  }) {
    return FcmfidResponseSchema(
      fid: fid ?? this.fid,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is FcmfidResponseSchema &&
            fid == other.fid &&
            active == other.active &&
            createdAt == other.createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(fid, active, createdAt);
  }

  @override
  String toString() {
    return 'FcmfidResponseSchema(fid: $fid, active: $active, createdAt: $createdAt)';
  }
}
