import 'dart:async';

import 'package:totem_app/core/api/lib/totem_mobile_api.dart';
import 'package:totem_app/features/sessions/controllers/session_types.dart';

class SessionKeeperPresenceController {
  SessionKeeperPresenceController({
    required this.disableMicrophone,
    required this.markKeeperDisconnected,
    required this.disconnect,
  });

  final AsyncCallback disableMicrophone;
  final BoolCallback markKeeperDisconnected;
  final AsyncCallback disconnect;

  static const disconnectionTimeout = Duration(minutes: 3);
  Timer? _keeperDisconnectedTimer;

  void onKeeperDisconnected(RoomStatus status) {
    if (status != RoomStatus.active) return;

    unawaited(disableMicrophone());

    _keeperDisconnectedTimer?.cancel();
    _keeperDisconnectedTimer = Timer(disconnectionTimeout, () {
      unawaited(onKeeperDisconnectedTimeout());
    });

    markKeeperDisconnected(true);
  }

  void onKeeperConnected() {
    _keeperDisconnectedTimer?.cancel();
    _keeperDisconnectedTimer = null;

    markKeeperDisconnected(false);
  }

  Future<void> onKeeperDisconnectedTimeout() async {
    _keeperDisconnectedTimer?.cancel();
    _keeperDisconnectedTimer = null;

    await disconnect();
  }

  void dispose() {
    _keeperDisconnectedTimer?.cancel();
    _keeperDisconnectedTimer = null;
  }
}
