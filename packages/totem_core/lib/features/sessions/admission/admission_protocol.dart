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
        AdmissionJoined() => 'admission.joined',
        AdmissionJoinFailed() => 'admission.joinFailed',
        AdmissionRosterRequest() => 'roster.request',
        AdmissionRosterSnapshot() => 'roster.snapshot',
        AdmissionRosterUpdated() => 'roster.updated',
      },
      'id': packet.id,
      'from': packet.senderIdentity,
      'to': packet.recipientIdentity,
      'expiresAt': packet.expiresAt.millisecondsSinceEpoch,
      if (packet case AdmissionRequest(:final displayName)) 'name': displayName,
      if (packet case AdmissionDecision(:final approved)) 'approved': approved,
      if (packet case AdmissionRosterRequest(:final sessionIdentity))
        'session': sessionIdentity,
      if (packet case AdmissionRosterSnapshot(
        :final sessionIdentity,
        :final keeperGeneration,
        :final revision,
        :final members,
        :final requestId,
      )) ...{
        'session': sessionIdentity,
        'generation': keeperGeneration,
        'revision': revision,
        'members': members,
        'requestId': ?requestId,
      },
      if (packet case AdmissionRosterUpdated(
        :final sessionIdentity,
        :final keeperGeneration,
        :final revision,
        :final members,
      )) ...{
        'session': sessionIdentity,
        'generation': keeperGeneration,
        'revision': revision,
        'members': members,
      },
    }),
  );

  /// Build a receipt for the original attempt, to send on the NEW, normally
  /// connected room after SessionController.join succeeds.
  static AdmissionJoined joined(AdmissionRequest request) => AdmissionJoined(
    id: request.id,
    senderIdentity: request.senderIdentity,
    recipientIdentity: request.recipientIdentity,
    expiresAt: request.expiresAt,
  );

  /// Optional failure receipt, only when a connected room can send it.
  static AdmissionJoinFailed joinFailed(AdmissionRequest request) =>
      AdmissionJoinFailed(
        id: request.id,
        senderIdentity: request.senderIdentity,
        recipientIdentity: request.recipientIdentity,
        expiresAt: request.expiresAt,
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
      if (value['kind'] == 'admission.joined' ||
          value['kind'] == 'admission.joinFailed') {
        if (value.containsKey('name') || value.containsKey('approved')) {
          return null;
        }
        return value['kind'] == 'admission.joined'
            ? AdmissionJoined(
                id: id,
                senderIdentity: from as String,
                recipientIdentity: to,
                expiresAt: expiration,
              )
            : AdmissionJoinFailed(
                id: id,
                senderIdentity: from as String,
                recipientIdentity: to,
                expiresAt: expiration,
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
      final session = value['session'];
      if (session is! String || session.isEmpty || session.length > 256) {
        return null;
      }
      if (value['kind'] == 'roster.request') {
        if (value.containsKey('generation') ||
            value.containsKey('revision') ||
            value.containsKey('members') ||
            value.containsKey('requestId')) {
          return null;
        }
        return AdmissionRosterRequest(
          id: id,
          senderIdentity: from as String,
          recipientIdentity: to,
          expiresAt: expiration,
          sessionIdentity: session,
        );
      }
      final generation = value['generation'];
      final revision = value['revision'];
      final members = value['members'];
      if ((value['kind'] != 'roster.snapshot' &&
              value['kind'] != 'roster.updated') ||
          generation is! String ||
          generation.isEmpty ||
          generation.length > 128 ||
          revision is! int ||
          revision < 0 ||
          members is! List ||
          members.length > 256 ||
          members.any(
            (member) =>
                member is! String || member.isEmpty || member.length > 256,
          ) ||
          members.toSet().length != members.length) {
        return null;
      }
      final requestId = value['requestId'];
      if (requestId != null &&
          (requestId is! String ||
              requestId.isEmpty ||
              requestId.length > 128)) {
        return null;
      }
      if (value['kind'] == 'roster.updated' && requestId != null) return null;
      final rosterMembers = List<String>.unmodifiable(members.cast<String>());
      return value['kind'] == 'roster.snapshot'
          ? AdmissionRosterSnapshot(
              id: id,
              senderIdentity: from as String,
              recipientIdentity: to,
              expiresAt: expiration,
              sessionIdentity: session,
              keeperGeneration: generation,
              revision: revision,
              members: rosterMembers,
              requestId: requestId as String?,
            )
          : AdmissionRosterUpdated(
              id: id,
              senderIdentity: from as String,
              recipientIdentity: to,
              expiresAt: expiration,
              sessionIdentity: session,
              keeperGeneration: generation,
              revision: revision,
              members: rosterMembers,
            );
    } on FormatException {
      return null;
    }
  }
}

sealed class AdmissionPacket {
  const AdmissionPacket({
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
  const AdmissionRequest({
    required super.id,
    required super.senderIdentity,
    required super.recipientIdentity,
    required super.expiresAt,
    required this.displayName,
  });

  final String displayName;
}

final class AdmissionCancel extends AdmissionPacket {
  const AdmissionCancel({
    required super.id,
    required super.senderIdentity,
    required super.recipientIdentity,
    required super.expiresAt,
  });
}

/// Keeper presence advertisement; it does not grant admission.
final class AdmissionHello extends AdmissionPacket {
  const AdmissionHello({
    required super.id,
    required super.senderIdentity,
    required super.recipientIdentity,
    required super.expiresAt,
  });
}

/// Receipt sent only from the participant's new normal room connection.
final class AdmissionJoined extends AdmissionPacket {
  const AdmissionJoined({
    required super.id,
    required super.senderIdentity,
    required super.recipientIdentity,
    required super.expiresAt,
  });
}

final class AdmissionJoinFailed extends AdmissionPacket {
  const AdmissionJoinFailed({
    required super.id,
    required super.senderIdentity,
    required super.recipientIdentity,
    required super.expiresAt,
  });
}

final class AdmissionDecision extends AdmissionPacket {
  const AdmissionDecision({
    required super.id,
    required super.senderIdentity,
    required super.recipientIdentity,
    required super.expiresAt,
    required this.approved,
  });

  final bool approved;
}

/// Requests the current, session-bound admitted-participant roster.
final class AdmissionRosterRequest extends AdmissionPacket {
  const AdmissionRosterRequest({
    required super.id,
    required super.senderIdentity,
    required super.recipientIdentity,
    required super.expiresAt,
    required this.sessionIdentity,
  });

  final String sessionIdentity;
}

sealed class AdmissionRosterPacket extends AdmissionPacket {
  const AdmissionRosterPacket({
    required super.id,
    required super.senderIdentity,
    required super.recipientIdentity,
    required super.expiresAt,
    required this.sessionIdentity,
    required this.keeperGeneration,
    required this.revision,
    required this.members,
  });

  final String sessionIdentity;
  final String keeperGeneration;
  final int revision;
  final List<String> members;
}

/// An authoritative full roster. [requestId] echoes a roster request when this
/// is a response; absent values are presence advertisements.
final class AdmissionRosterSnapshot extends AdmissionRosterPacket {
  const AdmissionRosterSnapshot({
    required super.id,
    required super.senderIdentity,
    required super.recipientIdentity,
    required super.expiresAt,
    required super.sessionIdentity,
    required super.keeperGeneration,
    required super.revision,
    required super.members,
    this.requestId,
  });

  final String? requestId;
}

/// An authoritative replacement roster at the next keeper revision.
final class AdmissionRosterUpdated extends AdmissionRosterPacket {
  const AdmissionRosterUpdated({
    required super.id,
    required super.senderIdentity,
    required super.recipientIdentity,
    required super.expiresAt,
    required super.sessionIdentity,
    required super.keeperGeneration,
    required super.revision,
    required super.members,
  });
}
