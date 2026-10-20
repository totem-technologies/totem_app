import 'dart:convert';

/// Client-side waiting-room protocol. This is not an access-control boundary:
/// LiveKit tokens must still enforce server-side room permissions separately.
abstract final class AdmissionProtocol {
  static const topic = 'totem.admission.v1';
  static const version = 1;
  static const lifetime = Duration(minutes: 2);
  // A second of headroom lets consecutive requests have distinct millisecond
  // expirations without allowing unbounded future-dated packets.
  static const maxLifetime = Duration(minutes: 2, seconds: 1);
  static const maxPayloadBytes = 4096;

  static List<int> encode(AdmissionPacket packet) => utf8.encode(
    jsonEncode({
      'v': version,
      'kind': switch (packet) {
        AdmissionRequest() => 'request',
        AdmissionDecision() => 'decision',
        AdmissionCancel() => 'cancel',
        AdmissionHello() => 'hello',
      },
      'id': packet.id,
      'from': packet.senderIdentity,
      'to': packet.recipientIdentity,
      'expiresAt': packet.expiresAt.millisecondsSinceEpoch,
      if (packet case AdmissionRequest(:final displayName)) 'name': displayName,
      if (packet case AdmissionDecision(:final approved)) 'approved': approved,
    }),
  );

  /// Rejects malformed, expired, unsupported, and implausibly long-lived packets.
  /// [senderIdentity] must come from LiveKit's participant event, not the JSON.
  static AdmissionPacket? decode(
    List<int> bytes, {
    required String? senderIdentity,
    required DateTime now,
  }) {
    if (senderIdentity == null ||
        senderIdentity.isEmpty ||
        bytes.length > maxPayloadBytes) {
      return null;
    }
    try {
      final value = jsonDecode(utf8.decode(bytes));
      if (value is! Map<String, dynamic> || value['v'] != version) return null;
      final id = value['id'];
      final from = value['from'];
      final to = value['to'];
      final expiresAt = value['expiresAt'];
      if (id is! String ||
          id.isEmpty ||
          id.length > 128 ||
          from != senderIdentity ||
          senderIdentity.length > 256 ||
          to is! String ||
          to.isEmpty ||
          to.length > 256 ||
          expiresAt is! int) {
        return null;
      }
      if (value['kind'] == 'hello') {
        if (expiresAt < -8640000000000000 || expiresAt > 8640000000000000) {
          return null;
        }
        return AdmissionHello(
          id: id,
          senderIdentity: from as String,
          recipientIdentity: to,
          expiresAt: DateTime.fromMillisecondsSinceEpoch(expiresAt),
        );
      }
      final nowMillis = now.millisecondsSinceEpoch;
      if (expiresAt <= nowMillis ||
          expiresAt > 8640000000000000 ||
          expiresAt > nowMillis + maxLifetime.inMilliseconds) {
        return null;
      }
      final expiration = DateTime.fromMillisecondsSinceEpoch(expiresAt);
      if (!expiration.isAfter(now)) {
        return null;
      }
      if (value['kind'] == 'request') {
        final name = value['name'];
        if (name is! String || name.trim().isEmpty || name.length > 120) {
          return null;
        }
        return AdmissionRequest(
          id: id,
          senderIdentity: from as String,
          recipientIdentity: to,
          expiresAt: expiration,
          displayName: name,
        );
      }
      if (value['kind'] == 'cancel') {
        return AdmissionCancel(
          id: id,
          senderIdentity: from as String,
          recipientIdentity: to,
          expiresAt: expiration,
        );
      }
      if (value['kind'] == 'decision' && value['approved'] is bool) {
        return AdmissionDecision(
          id: id,
          senderIdentity: from as String,
          recipientIdentity: to,
          expiresAt: expiration,
          approved: value['approved'] as bool,
        );
      }
    } on FormatException {
      return null;
    }
    return null;
  }
}

sealed class AdmissionPacket {
  const new({
    required this.id,
    required this.senderIdentity,
    required this.recipientIdentity,
    required this.expiresAt,
  });

  final String id;
  final String senderIdentity;
  final String recipientIdentity;
  final DateTime expiresAt;
}

final class AdmissionRequest extends AdmissionPacket {
  const new({
    required super.id,
    required super.senderIdentity,
    required super.recipientIdentity,
    required super.expiresAt,
    required this.displayName,
  });

  final String displayName;
}

final class AdmissionCancel extends AdmissionPacket {
  const new({
    required super.id,
    required super.senderIdentity,
    required super.recipientIdentity,
    required super.expiresAt,
  });
}

/// Keeper presence advertisement; it does not grant admission.
final class AdmissionHello extends AdmissionPacket {
  const new({
    required super.id,
    required super.senderIdentity,
    required super.recipientIdentity,
    required super.expiresAt,
  });
}

final class AdmissionDecision extends AdmissionPacket {
  const new({
    required super.id,
    required super.senderIdentity,
    required super.recipientIdentity,
    required super.expiresAt,
    required this.approved,
  });

  final bool approved;
}
