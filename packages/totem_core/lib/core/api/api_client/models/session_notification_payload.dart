// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:degenerate_runtime/degenerate_runtime.dart';

@immutable
final class NotificationType {
  const NotificationType._(this.value);

  factory NotificationType.fromJson(String json) {
    return switch (json) {
      'session_starting' => sessionStarting,
      'session_advertisement' => sessionAdvertisement,
      'missed_session' => missedSession,
      _ => NotificationType._(json),
    };
  }

  static const NotificationType sessionStarting = NotificationType._(
    'session_starting',
  );

  static const NotificationType sessionAdvertisement = NotificationType._(
    'session_advertisement',
  );

  static const NotificationType missedSession = NotificationType._(
    'missed_session',
  );

  static const List<NotificationType> values = [
    sessionStarting,
    sessionAdvertisement,
    missedSession,
  ];

  final String value;

  String toJson() {
    return value;
  }

  /// Whether this value is unknown (not defined in the OpenAPI spec).
  bool get isUnknown {
    return !values.contains(this);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is NotificationType && other.value == value;
  }

  @override
  int get hashCode {
    return value.hashCode;
  }

  @override
  String toString() {
    return 'NotificationType($value)';
  }
}

@immutable
final class SessionNotificationPayload {
  const SessionNotificationPayload({
    required this.type,
    required this.spaceSlug,
    required this.sessionSlug,
  });

  factory SessionNotificationPayload.fromJson(Map<String, dynamic> json) {
    return SessionNotificationPayload(
      type: NotificationType.fromJson(json['type'] as String),
      spaceSlug: json['space_slug'] as String,
      sessionSlug: json['session_slug'] as String,
    );
  }

  final NotificationType type;

  final String spaceSlug;

  final String sessionSlug;

  Map<String, dynamic> toJson() {
    return {
      'type': type.toJson(),
      'space_slug': spaceSlug,
      'session_slug': sessionSlug,
    };
  }

  static bool canParse(Map<String, dynamic> json) {
    return json.containsKey('type') &&
        json.containsKey('space_slug') &&
        json['space_slug'] is String &&
        json.containsKey('session_slug') &&
        json['session_slug'] is String;
  }

  SessionNotificationPayload copyWith({
    NotificationType? type,
    String? spaceSlug,
    String? sessionSlug,
  }) {
    return SessionNotificationPayload(
      type: type ?? this.type,
      spaceSlug: spaceSlug ?? this.spaceSlug,
      sessionSlug: sessionSlug ?? this.sessionSlug,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SessionNotificationPayload &&
            type == other.type &&
            spaceSlug == other.spaceSlug &&
            sessionSlug == other.sessionSlug;
  }

  @override
  int get hashCode {
    return Object.hash(type, spaceSlug, sessionSlug);
  }

  @override
  String toString() {
    return 'SessionNotificationPayload(type: $type, spaceSlug: $spaceSlug, sessionSlug: $sessionSlug)';
  }
}
