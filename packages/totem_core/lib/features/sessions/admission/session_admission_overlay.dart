import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart'
    hide Session, SessionOptions;
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/features/sessions/admission/admission_controllers.dart';
import 'package:totem_core/features/sessions/admission/admission_protocol.dart';
import 'package:totem_core/features/sessions/admission/admission_transport.dart';
import 'package:totem_core/features/sessions/admission/keeper_admission_panel.dart';
import 'package:totem_core/features/sessions/controllers/core/session_state.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/screens/chat.dart';
import 'package:totem_core/features/sessions/widgets/session_waiting_queue_button.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/notifications.dart';

class SessionAdmissionOverlay extends ConsumerStatefulWidget {
  const SessionAdmissionOverlay({required this.sessionSlug, super.key});

  final String sessionSlug;

  @override
  ConsumerState<SessionAdmissionOverlay> createState() =>
      _SessionAdmissionOverlayState();
}

class _SessionAdmissionOverlayState
    extends ConsumerState<SessionAdmissionOverlay> {
  final _notificationController = NotificationController();
  late final AdmittedSessionParticipantIdentities _admittedIdentities;

  LiveKitAdmissionTransport? _transport;
  KeeperAdmissionController? _keeperController;
  ClientAdmissionRosterController? _clientController;
  // Cancelled by _detachAdmission.
  // ignore: cancel_subscriptions
  StreamSubscription<void>? _keeperChanges;
  // Cancelled by _detachAdmission.
  // ignore: cancel_subscriptions
  StreamSubscription<AdmissionRoster?>? _clientChanges;

  Room? _room;
  String? _keeperIdentity;
  KeeperAdmissionRosterStore? _keeperRosterStore;
  String? _rosterStoreSessionSlug;
  var _admittedUpdateVersion = 0;
  bool _dismissed = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _admittedIdentities = ref.read(
      admittedSessionParticipantIdentitiesProvider.notifier,
    );
    ref
      ..listenManual(
        currentSessionStateProvider,
        (_, _) => _syncAdmission(),
        fireImmediately: true,
      )
      ..listenManual(
        currentSessionEventProvider,
        (_, _) => _syncAdmission(),
        fireImmediately: true,
      )
      ..listenManual(
        currentSessionProvider,
        (_, _) => _syncAdmission(),
        fireImmediately: true,
      );
  }

  @override
  void didUpdateWidget(SessionAdmissionOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionSlug == widget.sessionSlug) return;

    _admittedUpdateVersion++;
    _keeperRosterStore = null;
    _rosterStoreSessionSlug = null;
    unawaited(_detachAdmission());
    _syncAdmission();
  }

  @override
  void dispose() {
    unawaited(_detachAdmission(clearAdmitted: false));
    _notificationController.dispose();
    super.dispose();
  }

  void _syncAdmission() {
    if (!mounted) return;
    final state = ref.read(currentSessionStateProvider);
    final event = ref.read(currentSessionEventProvider);
    final room = ref.read(currentSessionProvider)?.room;
    final keeperIdentity = state?.roomState.keeper;
    final connected = state?.connection.state == RoomConnectionState.connected;
    final active =
        connected &&
        state?.roomState.status != RoomStatus.ended &&
        event?.ended != true &&
        room != null &&
        keeperIdentity != null &&
        keeperIdentity.isNotEmpty;
    if (!active) {
      if (_hasAdmission) unawaited(_detachAdmission());
      return;
    }

    final isKeeper = room.localParticipant?.identity == keeperIdentity;
    final controllerActive = isKeeper
        ? _keeperController != null
        : _clientController != null;
    if (identical(_room, room) &&
        _keeperIdentity == keeperIdentity &&
        controllerActive) {
      return;
    }

    unawaited(_detachAdmission());
    _syncAdmittedIdentities(const []);
    final transport = LiveKitAdmissionTransport(room);
    _transport = transport;
    _room = room;
    _keeperIdentity = keeperIdentity;
    _dismissed = false;

    if (isKeeper) {
      final controller = KeeperAdmissionController(
        channel: transport,
        keeperIdentity: _currentKeeperIdentity,
        sessionIdentity: widget.sessionSlug,
        rosterStore: _rosterStoreFor(widget.sessionSlug),
      );
      _keeperController = controller;
      _syncAdmittedIdentities(controller.roster);
      _keeperChanges = controller.changes.listen((_) {
        if (!mounted || !identical(_keeperController, controller)) return;
        _syncAdmittedIdentities(controller.roster);
        setState(() {
          if (controller.requests.isEmpty) _dismissed = false;
        });
      });
    } else {
      final controller = ClientAdmissionRosterController(
        channel: transport,
        keeperIdentity: _currentKeeperIdentity,
        sessionIdentity: widget.sessionSlug,
      );
      _clientController = controller;
      _syncAdmittedIdentities(controller.roster?.members ?? const []);
      _clientChanges = controller.changes.listen((roster) {
        if (!mounted || !identical(_clientController, controller)) return;
        _syncAdmittedIdentities(roster?.members ?? const []);
      });
    }
    setState(() {});
  }

  String _currentKeeperIdentity() => mounted
      ? ref.read(currentSessionStateProvider)?.roomState.keeper ?? ''
      : '';

  bool get _hasAdmission =>
      _keeperController != null ||
      _clientController != null ||
      _transport != null;

  KeeperAdmissionRosterStore _rosterStoreFor(String sessionSlug) {
    if (_rosterStoreSessionSlug != sessionSlug) {
      _rosterStoreSessionSlug = sessionSlug;
      _keeperRosterStore = KeeperAdmissionRosterStore();
    }
    return _keeperRosterStore!;
  }

  void _syncAdmittedIdentities(Iterable<String> identities) {
    final roster = List<String>.of(identities);
    final version = ++_admittedUpdateVersion;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || version != _admittedUpdateVersion) return;
      _admittedIdentities.update(roster);
      ref
          .read(currentSessionProvider)
          ?.updateAdmittedMediaRecipients(
            roster.toSet(),
          );
    });
  }

  Future<void> _detachAdmission({bool clearAdmitted = true}) {
    final keeperController = _keeperController;
    final clientController = _clientController;
    final transport = _transport;
    final keeperChanges = _keeperChanges;
    final clientChanges = _clientChanges;
    _keeperController = null;
    _clientController = null;
    _transport = null;
    _keeperChanges = null;
    _clientChanges = null;
    _room = null;
    _keeperIdentity = null;
    _busy = false;
    if (clearAdmitted) _syncAdmittedIdentities(const []);

    return Future.wait<void>([
      if (keeperChanges != null) keeperChanges.cancel(),
      if (clientChanges != null) clientChanges.cancel(),
    ]).then((_) async {
      await keeperController?.dispose();
      await clientController?.dispose();
      await transport?.dispose();
    });
  }

  Future<void> _decide(AdmissionRequest request, bool approve) async {
    final controller = _keeperController;
    if (controller == null || _busy) return;
    setState(() => _busy = true);
    try {
      await _sendDecision(controller, request, approve);
    } finally {
      if (mounted && identical(_keeperController, controller)) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _admitAll() async {
    final controller = _keeperController;
    if (controller == null || _busy) return;
    setState(() => _busy = true);
    try {
      for (final request in controller.requests) {
        if (!identical(_keeperController, controller)) break;
        await _sendDecision(controller, request, true);
      }
    } finally {
      if (mounted && identical(_keeperController, controller)) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _sendDecision(
    KeeperAdmissionController controller,
    AdmissionRequest request,
    bool approve,
  ) async {
    try {
      if (approve) {
        await controller.approve(request.id, request.senderIdentity);
      } else {
        await controller.deny(request.id, request.senderIdentity);
      }
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Could not send admission decision',
      );
      if (mounted && identical(_keeperController, controller)) {
        _notificationController.showError(
          context,
          icon: TotemIcons.errorOutlined,
          title: 'Could not update the queue',
          message: 'Please check your connection and try again.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _keeperController;
    if (controller == null || controller.attempts.isEmpty) {
      // The room Stack has only positioned video children; keep it expanded
      // even when the queue has nothing to display.
      return const SizedBox.expand();
    }

    final desktop = shouldDockSessionChat(context);
    return Positioned(
      top: desktop ? 16 : null,
      right: 16,
      left: desktop ? null : 16,
      bottom: desktop ? null : 16,
      child: SafeArea(
        child: Align(
          alignment: desktop ? Alignment.topRight : Alignment.bottomCenter,
          child: _dismissed
              ? SessionWaitingQueueButton(
                  count: controller.requests.length,
                  label:
                      controller.requests.isEmpty &&
                          controller.attempts.any(
                            (attempt) =>
                                attempt.status == KeeperAdmissionStatus.joining,
                          )
                      ? 'Admission in progress'
                      : null,
                  onPressed: () => setState(() => _dismissed = false),
                )
              : KeeperAdmissionPanel(
                  requests: controller.requests,
                  attempts: controller.attempts,
                  busy: _busy,
                  desktop: desktop,
                  onDecision: _decide,
                  onAdmitAll: () => unawaited(_admitAll()),
                  onClose: () => setState(() => _dismissed = true),
                ),
        ),
      ),
    );
  }
}
