// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:degenerate_runtime/degenerate_runtime.dart';
import 'admission_join_state.dart';

/// Token and server-owned admission snapshot (absent during legacy rollout).
@immutable
final class JoinResponse {
  const JoinResponse({
    required this.token,
    required this.isAlreadyPresent,
    this.admission = const Omittable.absent(),
  });

  factory JoinResponse.fromJson(Map<String, dynamic> json) {
    return JoinResponse(
      token: json['token'] as String,
      isAlreadyPresent: json['is_already_present'] as bool,
      admission: json.containsKey('admission')
          ? Omittable(
              json['admission'] != null
                  ? AdmissionJoinState.fromJson(
                      json['admission'] as Map<String, dynamic>,
                    )
                  : null,
            )
          : const Omittable.absent(),
    );
  }

  final String token;

  final bool isAlreadyPresent;

  final Omittable<AdmissionJoinState?> admission;

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'is_already_present': isAlreadyPresent,
      if (admission.isPresent) 'admission': admission.value?.toJson(),
    };
  }

  static bool canParse(Map<String, dynamic> json) {
    return json.containsKey('token') &&
        json['token'] is String &&
        json.containsKey('is_already_present') &&
        json['is_already_present'] is bool;
  }

  JoinResponse copyWith({
    String? token,
    bool? isAlreadyPresent,
    Omittable<AdmissionJoinState?>? admission,
  }) {
    return JoinResponse(
      token: token ?? this.token,
      isAlreadyPresent: isAlreadyPresent ?? this.isAlreadyPresent,
      admission: admission ?? this.admission,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is JoinResponse &&
            token == other.token &&
            isAlreadyPresent == other.isAlreadyPresent &&
            admission == other.admission;
  }

  @override
  int get hashCode {
    return Object.hash(token, isAlreadyPresent, admission);
  }

  @override
  String toString() {
    return 'JoinResponse(token: $token, isAlreadyPresent: $isAlreadyPresent, admission: $admission)';
  }
}
