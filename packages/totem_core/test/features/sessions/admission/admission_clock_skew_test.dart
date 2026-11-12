import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/features/sessions/admission/admission_protocol.dart';

class _PacketCase {
  const _PacketCase(this.name, this.lifetime, this.create);

  final String name;
  final Duration lifetime;
  final AdmissionPacket Function(DateTime expiresAt) create;
}

const _sender = 'sender';
const _recipient = 'recipient';

final _packetCases = <_PacketCase>[
  _PacketCase(
    'request',
    AdmissionProtocol.requestLifetime,
    (expiresAt) => AdmissionRequest(
      id: 'request',
      senderIdentity: _sender,
      recipientIdentity: _recipient,
      expiresAt: expiresAt,
      displayName: 'Sender',
    ),
  ),
  _PacketCase(
    'decision',
    AdmissionProtocol.requestLifetime,
    (expiresAt) => AdmissionDecision(
      id: 'decision',
      senderIdentity: _sender,
      recipientIdentity: _recipient,
      expiresAt: expiresAt,
      approved: true,
    ),
  ),
  _PacketCase(
    'cancel',
    AdmissionProtocol.requestLifetime,
    (expiresAt) => AdmissionCancel(
      id: 'cancel',
      senderIdentity: _sender,
      recipientIdentity: _recipient,
      expiresAt: expiresAt,
    ),
  ),
  _PacketCase(
    'joined',
    AdmissionProtocol.requestLifetime,
    (expiresAt) => AdmissionJoined(
      id: 'joined',
      senderIdentity: _sender,
      recipientIdentity: _recipient,
      expiresAt: expiresAt,
    ),
  ),
  _PacketCase(
    'joinFailed',
    AdmissionProtocol.requestLifetime,
    (expiresAt) => AdmissionJoinFailed(
      id: 'join-failed',
      senderIdentity: _sender,
      recipientIdentity: _recipient,
      expiresAt: expiresAt,
    ),
  ),
  _PacketCase(
    'roster.request',
    AdmissionProtocol.lifetime,
    (expiresAt) => AdmissionRosterRequest(
      id: 'roster-request',
      senderIdentity: _sender,
      recipientIdentity: _recipient,
      expiresAt: expiresAt,
      sessionIdentity: 'session',
    ),
  ),
  _PacketCase(
    'roster.snapshot',
    AdmissionProtocol.lifetime,
    (expiresAt) => AdmissionRosterSnapshot(
      id: 'roster-snapshot',
      senderIdentity: _sender,
      recipientIdentity: _recipient,
      expiresAt: expiresAt,
      sessionIdentity: 'session',
      keeperGeneration: 'generation',
      revision: 1,
      members: const ['member'],
    ),
  ),
  _PacketCase(
    'roster.updated',
    AdmissionProtocol.lifetime,
    (expiresAt) => AdmissionRosterUpdated(
      id: 'roster-updated',
      senderIdentity: _sender,
      recipientIdentity: _recipient,
      expiresAt: expiresAt,
      sessionIdentity: 'session',
      keeperGeneration: 'generation',
      revision: 1,
      members: const ['member'],
    ),
  ),
];

AdmissionPacket? _decode(AdmissionPacket packet, DateTime receiverNow) =>
    AdmissionProtocol.decode(
      AdmissionProtocol.encode(packet),
      senderIdentity: _sender,
      now: receiverNow,
    );

void main() {
  final senderNow = DateTime.utc(2031, 6, 15, 12);
  final offsets = [
    const Duration(seconds: 3),
    const Duration(seconds: 30),
    const Duration(seconds: -3),
    const Duration(seconds: -30),
  ];

  test('non-hello packets accept sender lifetime across clock offsets', () {
    for (final packetCase in _packetCases) {
      final packet = packetCase.create(senderNow.add(packetCase.lifetime));
      for (final offset in offsets) {
        check(_decode(packet, senderNow.add(offset))).isNotNull();
      }
    }
  });

  test('clock-skew allowance ends at each packet lifetime horizon', () {
    final receiverNow = DateTime.utc(2031, 6, 15, 12);
    final horizons = [
      (AdmissionProtocol.maxRequestLifetime, _packetCases.first),
      (AdmissionProtocol.maxLifetime, _packetCases[5]),
    ];

    for (final (maxLifetime, packetCase) in horizons) {
      final horizon = receiverNow.add(
        maxLifetime + AdmissionProtocol.maxClockSkew,
      );
      check(_decode(packetCase.create(horizon), receiverNow)).isNotNull();
      check(
        _decode(
          packetCase.create(horizon.add(const Duration(milliseconds: 1))),
          receiverNow,
        ),
      ).isNull();
    }
  });

  test('non-hello packets expiring at receiver now remain invalid', () {
    final receiverNow = DateTime.utc(2031, 6, 15, 12);

    for (final packetCase in _packetCases) {
      check(_decode(packetCase.create(receiverNow), receiverNow)).isNull();
    }
  });
}
