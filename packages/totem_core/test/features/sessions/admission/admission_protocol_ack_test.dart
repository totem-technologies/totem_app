import 'dart:convert';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/features/sessions/admission/admission_protocol.dart';

void main() {
  final now = DateTime.utc(2026);
  final ack = AdmissionRosterAck(
    id: 'ack',
    senderIdentity: 'guest',
    recipientIdentity: 'keeper',
    expiresAt: now.add(AdmissionProtocol.lifetime),
    sessionIdentity: 'session',
    keeperGeneration: 'generation',
    revision: 3,
  );

  test('ACK round trips its applied revision without roster members', () {
    final bytes = AdmissionProtocol.encode(ack);
    final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    check(json['kind']).equals('roster.ack');
    check(json.containsKey('members')).isFalse();
    final decoded =
        AdmissionProtocol.decode(bytes, senderIdentity: 'guest', now: now)!
            as AdmissionRosterAck;
    check(decoded.id).equals(ack.id);
    check(decoded.senderIdentity).equals(ack.senderIdentity);
    check(decoded.recipientIdentity).equals(ack.recipientIdentity);
    check(
      decoded.expiresAt.millisecondsSinceEpoch,
    ).equals(ack.expiresAt.millisecondsSinceEpoch);
    check(decoded.sessionIdentity).equals(ack.sessionIdentity);
    check(decoded.keeperGeneration).equals(ack.keeperGeneration);
    check(decoded.revision).equals(ack.revision);
  });

  test('ACK rejects spoofing, expired and malformed packets', () {
    final json =
        jsonDecode(utf8.decode(AdmissionProtocol.encode(ack)))
            as Map<String, dynamic>;
    AdmissionPacket? decode(
      Map<String, dynamic> value, {
      String? sender = 'guest',
    }) => AdmissionProtocol.decode(
      utf8.encode(jsonEncode(value)),
      senderIdentity: sender,
      now: now,
    );

    check(decode(json, sender: 'attacker')).isNull();
    check(decode(json, sender: null)).isNull();
    for (final changes in <Map<String, dynamic>>[
      {'expiresAt': now.millisecondsSinceEpoch},
      {
        'expiresAt': now
            .add(
              AdmissionProtocol.maxLifetime +
                  AdmissionProtocol.maxClockSkew +
                  const Duration(milliseconds: 1),
            )
            .millisecondsSinceEpoch,
      },
      {'id': ''},
      {'to': ''},
      {'session': ''},
      {'session': 'x' * 257},
      {'generation': ''},
      {'generation': 'x' * 129},
      {'revision': -1},
      {'revision': 1.5},
      {'members': <String>[]},
      {'requestId': null},
      {'extra': 'x' * AdmissionProtocol.maxPayloadBytes},
    ]) {
      check(decode({...json, ...changes})).isNull();
    }
  });
}
