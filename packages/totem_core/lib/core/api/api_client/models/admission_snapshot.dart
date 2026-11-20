// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:degenerate_runtime/degenerate_runtime.dart';
import 'participant.dart';

@immutable
final class AdmissionSnapshot {
  const AdmissionSnapshot({
    required this.sessionSlug,
    required this.keeper,
    required this.roomVersion,
    required this.roomStatus,
    required this.approvalRequired,
    required this.settingsRevision,
    required this.version,
    required this.observedAt,
    required this.admittedCount,
    required this.activatedCount,
    required this.pendingCount,
    required this.participants,
    required this.waiting,
    required this.requests,
    required this.historyTruncated,
    this.presenceError = const Omittable.absent(),
    this.connectedCount = const Omittable.absent(),
    this.admissionCapacity,
    this.admissionSlotsUsed,
    this.waitingConnectionLimit,
    this.livekitConnectionLimit,
    this.waitingSlotsUsed = const Omittable.absent(),
    this.connectionSlotsUsed = const Omittable.absent(),
  });

  factory AdmissionSnapshot.fromJson(Map<String, dynamic> json) {
    return AdmissionSnapshot(
      sessionSlug: json['session_slug'] as String,
      keeper: json['keeper'] as String,
      roomVersion: (json['room_version'] as num).toInt(),
      roomStatus: json['room_status'] as String,
      approvalRequired: json['approval_required'] as bool,
      settingsRevision: (json['settings_revision'] as num).toInt(),
      version: (json['version'] as num).toInt(),
      observedAt: DateTime.parse(json['observed_at'] as String),
      presenceError: json.containsKey('presence_error')
          ? Omittable(json['presence_error'] as String?)
          : const Omittable.absent(),
      connectedCount: json.containsKey('connected_count')
          ? Omittable(
              json['connected_count'] != null
                  ? (json['connected_count'] as num).toInt()
                  : null,
            )
          : const Omittable.absent(),
      admittedCount: (json['admitted_count'] as num).toInt(),
      activatedCount: (json['activated_count'] as num).toInt(),
      pendingCount: (json['pending_count'] as num).toInt(),
      admissionCapacity: json['admission_capacity'] != null
          ? (json['admission_capacity'] as num).toInt()
          : null,
      admissionSlotsUsed: json['admission_slots_used'] != null
          ? (json['admission_slots_used'] as num).toInt()
          : null,
      waitingConnectionLimit: json['waiting_connection_limit'] != null
          ? (json['waiting_connection_limit'] as num).toInt()
          : null,
      livekitConnectionLimit: json['livekit_connection_limit'] != null
          ? (json['livekit_connection_limit'] as num).toInt()
          : null,
      waitingSlotsUsed: json.containsKey('waiting_slots_used')
          ? Omittable(
              json['waiting_slots_used'] != null
                  ? (json['waiting_slots_used'] as num).toInt()
                  : null,
            )
          : const Omittable.absent(),
      connectionSlotsUsed: json.containsKey('connection_slots_used')
          ? Omittable(
              json['connection_slots_used'] != null
                  ? (json['connection_slots_used'] as num).toInt()
                  : null,
            )
          : const Omittable.absent(),
      participants: (json['participants'] as List<dynamic>)
          .map((e) => Participant.fromJson(e as Map<String, dynamic>))
          .toList(),
      waiting: (json['waiting'] as List<dynamic>)
          .map((e) => Participant.fromJson(e as Map<String, dynamic>))
          .toList(),
      requests: (json['requests'] as List<dynamic>)
          .map((e) => Participant.fromJson(e as Map<String, dynamic>))
          .toList(),
      historyTruncated: json['history_truncated'] as bool,
    );
  }

  final String sessionSlug;

  final String keeper;

  final int roomVersion;

  final String roomStatus;

  final bool approvalRequired;

  final int settingsRevision;

  final int version;

  final DateTime observedAt;

  final Omittable<String?> presenceError;

  final Omittable<int?> connectedCount;

  final int admittedCount;

  final int activatedCount;

  final int pendingCount;

  final int? admissionCapacity;

  final int? admissionSlotsUsed;

  final int? waitingConnectionLimit;

  final int? livekitConnectionLimit;

  final Omittable<int?> waitingSlotsUsed;

  final Omittable<int?> connectionSlotsUsed;

  final List<Participant> participants;

  final List<Participant> waiting;

  final List<Participant> requests;

  final bool historyTruncated;

  /// The value with the schema default applied when absent.
  int get admissionCapacityOrDefault {
    return admissionCapacity ?? 0;
  }

  /// The value with the schema default applied when absent.
  int get admissionSlotsUsedOrDefault {
    return admissionSlotsUsed ?? 0;
  }

  /// The value with the schema default applied when absent.
  int get waitingConnectionLimitOrDefault {
    return waitingConnectionLimit ?? 5;
  }

  /// The value with the schema default applied when absent.
  int get livekitConnectionLimitOrDefault {
    return livekitConnectionLimit ?? 15;
  }

  Map<String, dynamic> toJson() {
    return {
      'session_slug': sessionSlug,
      'keeper': keeper,
      'room_version': roomVersion,
      'room_status': roomStatus,
      'approval_required': approvalRequired,
      'settings_revision': settingsRevision,
      'version': version,
      'observed_at': observedAt.toIso8601String(),
      if (presenceError.isPresent) 'presence_error': presenceError.value,
      if (connectedCount.isPresent) 'connected_count': connectedCount.value,
      'admitted_count': admittedCount,
      'activated_count': activatedCount,
      'pending_count': pendingCount,
      'admission_capacity': ?admissionCapacity,
      'admission_slots_used': ?admissionSlotsUsed,
      'waiting_connection_limit': ?waitingConnectionLimit,
      'livekit_connection_limit': ?livekitConnectionLimit,
      if (waitingSlotsUsed.isPresent)
        'waiting_slots_used': waitingSlotsUsed.value,
      if (connectionSlotsUsed.isPresent)
        'connection_slots_used': connectionSlotsUsed.value,
      'participants': participants.map((e) => e.toJson()).toList(),
      'waiting': waiting.map((e) => e.toJson()).toList(),
      'requests': requests.map((e) => e.toJson()).toList(),
      'history_truncated': historyTruncated,
    };
  }

  static bool canParse(Map<String, dynamic> json) {
    return json.containsKey('session_slug') &&
        json['session_slug'] is String &&
        json.containsKey('keeper') &&
        json['keeper'] is String &&
        json.containsKey('room_version') &&
        json['room_version'] is num &&
        json.containsKey('room_status') &&
        json['room_status'] is String &&
        json.containsKey('approval_required') &&
        json['approval_required'] is bool &&
        json.containsKey('settings_revision') &&
        json['settings_revision'] is num &&
        json.containsKey('version') &&
        json['version'] is num &&
        json.containsKey('observed_at') &&
        json['observed_at'] is String &&
        json.containsKey('admitted_count') &&
        json['admitted_count'] is num &&
        json.containsKey('activated_count') &&
        json['activated_count'] is num &&
        json.containsKey('pending_count') &&
        json['pending_count'] is num &&
        json.containsKey('participants') &&
        json.containsKey('waiting') &&
        json.containsKey('requests') &&
        json.containsKey('history_truncated') &&
        json['history_truncated'] is bool;
  }

  AdmissionSnapshot copyWith({
    String? sessionSlug,
    String? keeper,
    int? roomVersion,
    String? roomStatus,
    bool? approvalRequired,
    int? settingsRevision,
    int? version,
    DateTime? observedAt,
    Omittable<String?>? presenceError,
    Omittable<int?>? connectedCount,
    int? admittedCount,
    int? activatedCount,
    int? pendingCount,
    int? Function()? admissionCapacity,
    int? Function()? admissionSlotsUsed,
    int? Function()? waitingConnectionLimit,
    int? Function()? livekitConnectionLimit,
    Omittable<int?>? waitingSlotsUsed,
    Omittable<int?>? connectionSlotsUsed,
    List<Participant>? participants,
    List<Participant>? waiting,
    List<Participant>? requests,
    bool? historyTruncated,
  }) {
    return AdmissionSnapshot(
      sessionSlug: sessionSlug ?? this.sessionSlug,
      keeper: keeper ?? this.keeper,
      roomVersion: roomVersion ?? this.roomVersion,
      roomStatus: roomStatus ?? this.roomStatus,
      approvalRequired: approvalRequired ?? this.approvalRequired,
      settingsRevision: settingsRevision ?? this.settingsRevision,
      version: version ?? this.version,
      observedAt: observedAt ?? this.observedAt,
      presenceError: presenceError ?? this.presenceError,
      connectedCount: connectedCount ?? this.connectedCount,
      admittedCount: admittedCount ?? this.admittedCount,
      activatedCount: activatedCount ?? this.activatedCount,
      pendingCount: pendingCount ?? this.pendingCount,
      admissionCapacity: admissionCapacity != null
          ? admissionCapacity()
          : this.admissionCapacity,
      admissionSlotsUsed: admissionSlotsUsed != null
          ? admissionSlotsUsed()
          : this.admissionSlotsUsed,
      waitingConnectionLimit: waitingConnectionLimit != null
          ? waitingConnectionLimit()
          : this.waitingConnectionLimit,
      livekitConnectionLimit: livekitConnectionLimit != null
          ? livekitConnectionLimit()
          : this.livekitConnectionLimit,
      waitingSlotsUsed: waitingSlotsUsed ?? this.waitingSlotsUsed,
      connectionSlotsUsed: connectionSlotsUsed ?? this.connectionSlotsUsed,
      participants: participants ?? this.participants,
      waiting: waiting ?? this.waiting,
      requests: requests ?? this.requests,
      historyTruncated: historyTruncated ?? this.historyTruncated,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AdmissionSnapshot &&
            sessionSlug == other.sessionSlug &&
            keeper == other.keeper &&
            roomVersion == other.roomVersion &&
            roomStatus == other.roomStatus &&
            approvalRequired == other.approvalRequired &&
            settingsRevision == other.settingsRevision &&
            version == other.version &&
            observedAt == other.observedAt &&
            presenceError == other.presenceError &&
            connectedCount == other.connectedCount &&
            admittedCount == other.admittedCount &&
            activatedCount == other.activatedCount &&
            pendingCount == other.pendingCount &&
            admissionCapacity == other.admissionCapacity &&
            admissionSlotsUsed == other.admissionSlotsUsed &&
            waitingConnectionLimit == other.waitingConnectionLimit &&
            livekitConnectionLimit == other.livekitConnectionLimit &&
            waitingSlotsUsed == other.waitingSlotsUsed &&
            connectionSlotsUsed == other.connectionSlotsUsed &&
            listEquals(participants, other.participants) &&
            listEquals(waiting, other.waiting) &&
            listEquals(requests, other.requests) &&
            historyTruncated == other.historyTruncated;
  }

  @override
  int get hashCode {
    return Object.hashAll([
      sessionSlug,
      keeper,
      roomVersion,
      roomStatus,
      approvalRequired,
      settingsRevision,
      version,
      observedAt,
      presenceError,
      connectedCount,
      admittedCount,
      activatedCount,
      pendingCount,
      admissionCapacity,
      admissionSlotsUsed,
      waitingConnectionLimit,
      livekitConnectionLimit,
      waitingSlotsUsed,
      connectionSlotsUsed,
      Object.hashAll(participants),
      Object.hashAll(waiting),
      Object.hashAll(requests),
      historyTruncated,
    ]);
  }

  @override
  String toString() {
    return 'AdmissionSnapshot(sessionSlug: $sessionSlug, keeper: $keeper, roomVersion: $roomVersion, roomStatus: $roomStatus, approvalRequired: $approvalRequired, settingsRevision: $settingsRevision, version: $version, observedAt: $observedAt, presenceError: $presenceError, connectedCount: $connectedCount, admittedCount: $admittedCount, activatedCount: $activatedCount, pendingCount: $pendingCount, admissionCapacity: $admissionCapacity, admissionSlotsUsed: $admissionSlotsUsed, waitingConnectionLimit: $waitingConnectionLimit, livekitConnectionLimit: $livekitConnectionLimit, waitingSlotsUsed: $waitingSlotsUsed, connectionSlotsUsed: $connectionSlotsUsed, participants: $participants, waiting: $waiting, requests: $requests, historyTruncated: $historyTruncated)';
  }
}
