enum AdmissionStatus {
  idle,
  pending,
  approved,
  denied,
  expired,
  cancelled,
  ended,
  failed,
}

enum AdmissionKeeperAvailability { checking, absent, unresponsive, responsive }

enum ServerAdmissionAttemptStatus {
  pending,
  granting,
  approved,
  activated,
  declined,
  permanentlyDeclined,
  revoked,
  cancelled,
  superseded,
  expired;

  static ServerAdmissionAttemptStatus? parse(String? status) =>
      switch (status) {
        'pending' => pending,
        'granting' => granting,
        'approved' => approved,
        'activated' => activated,
        'declined' => declined,
        'permanently_declined' => permanentlyDeclined,
        'revoked' => revoked,
        'cancelled' => cancelled,
        'superseded' => superseded,
        'expired' => expired,
        _ => null,
      };

  bool get isResumable =>
      this == pending || this == granting || this == approved;
  bool get isAllowedJoinResponse => isResumable || this == activated;
  bool get hasAdmissionDecision => this == granting || isAuthorized;
  bool get isAuthorized => this == approved || this == activated;
  bool get hasDeadline => this == pending || this == granting;
}
