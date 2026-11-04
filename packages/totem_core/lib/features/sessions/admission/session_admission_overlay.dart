import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart'
    hide Session, SessionOptions;
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/features/sessions/admission/admission_controllers.dart';
import 'package:totem_core/features/sessions/admission/admission_protocol.dart';
import 'package:totem_core/features/sessions/admission/admission_transport.dart';
import 'package:totem_core/features/sessions/admission/declined_session_participants.dart';
import 'package:totem_core/features/sessions/admission/keeper_admission_panel.dart';
import 'package:totem_core/features/sessions/admission/session_admission_settings.dart';
import 'package:totem_core/features/sessions/controllers/core/session_state.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/widgets/session_side_panel.dart';
import 'package:totem_core/features/sessions/widgets/session_waiting_queue_button.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/notifications.dart';
import 'package:totem_core/shared/widgets/responsive_modal.dart';
import 'package:totem_core/shared/widgets/viewport_resolver.dart';

/// Owns admission connections while the room renders queue controls and panels
/// in its normal layout. Opening or closing a panel never recreates transport.
class SessionAdmissionOverlay extends ConsumerStatefulWidget {
  const SessionAdmissionOverlay({
    required this.sessionSlug,
    required this.child,
    super.key,
  });

  final String sessionSlug;
  final Widget child;

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
      )
      ..listenManual(
        sessionAdmissionSettingsProvider,
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
    final declinedIdentities = isKeeper
        ? ref
              .read(
                declinedSessionParticipantsProvider(
                  widget.sessionSlug,
                  keeperIdentity,
                ),
              )
              .value
        : null;
    // Do not approve anyone before the durable decline list is known.
    if (isKeeper && declinedIdentities == null) {
      if (_hasAdmission) unawaited(_detachAdmission());
      return;
    }
    final controllerActive = isKeeper
        ? _keeperController != null
        : _clientController != null;
    if (identical(_room, room) &&
        _keeperIdentity == keeperIdentity &&
        controllerActive) {
      if (declinedIdentities != null) {
        _keeperController?.setDeclinedIdentities(declinedIdentities);
      }
      _keeperController?.setApprovalRequired(
        ref.read(sessionAdmissionSettingsProvider),
      );
      return;
    }

    unawaited(_detachAdmission());
    _syncAdmittedIdentities(const []);
    final transport = LiveKitAdmissionTransport(room);
    _transport = transport;
    _room = room;
    _keeperIdentity = keeperIdentity;

    if (isKeeper) {
      final controller = KeeperAdmissionController(
        channel: transport,
        keeperIdentity: _currentKeeperIdentity,
        sessionIdentity: widget.sessionSlug,
        rosterStore: _rosterStoreFor(widget.sessionSlug),
        approvalRequired: ref.read(sessionAdmissionSettingsProvider),
        declinedIdentities: declinedIdentities!,
      );
      _keeperController = controller;
      _syncAdmittedIdentities(controller.roster);
      _keeperChanges = controller.changes.listen((_) {
        if (!mounted || !identical(_keeperController, controller)) return;
        _syncAdmittedIdentities(controller.roster);
        setState(() {});
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
    void update() {
      if (!mounted || version != _admittedUpdateVersion) return;
      _admittedIdentities.update(roster);
      ref
          .read(currentSessionProvider)
          ?.updateAdmittedMediaRecipients(
            roster.toSet(),
          );
    }

    if (WidgetsBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      update();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => update());
    }
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

  Future<void> _decide(
    AdmissionRequest request,
    bool approve, {
    bool permanently = false,
  }) async {
    final controller = _keeperController;
    if (controller == null || _busy) return;
    setState(() => _busy = true);
    try {
      await _sendDecision(
        controller,
        request,
        approve,
        permanently: permanently,
      );
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
    bool approve, {
    bool permanently = false,
  }) async {
    try {
      if (approve) {
        await controller.approve(request.id, request.senderIdentity);
      } else if (permanently) {
        final declined = ref.read(
          declinedSessionParticipantsProvider(
            widget.sessionSlug,
            controller.channel.localIdentity,
          ).notifier,
        );
        await controller.denyPermanently(
          request.id,
          request.senderIdentity,
          () => declined.decline(request.senderIdentity),
        );
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
    VoidCallback? retry;
    final keeper = ref.watch(keeperIdentityProvider);
    if (keeper != null &&
        ref.read(currentSessionProvider)?.room?.localParticipant?.identity ==
            keeper) {
      final provider = declinedSessionParticipantsProvider(
        widget.sessionSlug,
        keeper,
      );
      ref.listen(provider, (_, _) => _syncAdmission());
      final declined = ref.watch(provider);
      if (declined.hasError && !declined.hasValue) {
        retry = () => ref.invalidate(provider);
      }
    }
    final controller = _keeperController;
    final attempts =
        controller?.attempts
            .where(
              (attempt) => !controller.isPermanentlyDeclined(
                attempt.request.senderIdentity,
              ),
            )
            .toList() ??
        const <KeeperAdmissionAttempt>[];
    return _SessionAdmissionScope(
      requests: controller?.requests ?? const [],
      attempts: attempts,
      enabled: controller?.approvalRequired ?? false,
      busy: _busy,
      onRetry: retry,
      onDecision: _decide,
      onDeclinePermanently: (request) =>
          _decide(request, false, permanently: true),
      onAdmitAll: () => unawaited(_admitAll()),
      child: widget.child,
    );
  }
}

const sessionAdmissionRouteName = 'session-admission';

class _SessionAdmissionScope extends InheritedWidget {
  const _SessionAdmissionScope({
    required this.requests,
    required this.attempts,
    required this.enabled,
    required this.busy,
    required this.onDecision,
    required this.onDeclinePermanently,
    required this.onAdmitAll,
    required this.onRetry,
    required super.child,
  });

  final List<AdmissionRequest> requests;
  final List<KeeperAdmissionAttempt> attempts;
  final bool enabled;
  final bool busy;
  final VoidCallback? onRetry;
  final Future<void> Function(AdmissionRequest, bool) onDecision;
  final Future<void> Function(AdmissionRequest) onDeclinePermanently;
  final VoidCallback onAdmitAll;

  static _SessionAdmissionScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SessionAdmissionScope>();

  @override
  bool updateShouldNotify(_SessionAdmissionScope oldWidget) => true;
}

/// A queue control in normal Session layout; it never positions itself over video.
class SessionAdmissionQueueControl extends ConsumerWidget {
  const SessionAdmissionQueueControl({this.child, super.key});

  final Widget? child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admission = _SessionAdmissionScope.maybeOf(context);
    if (admission == null) return child ?? const SizedBox.shrink();
    final joining = admission.attempts.any(
      (attempt) => attempt.status == KeeperAdmissionStatus.joining,
    );
    final retry = admission.onRetry;
    if (retry == null &&
        (!admission.enabled || (admission.requests.isEmpty && !joining))) {
      return child ?? const SizedBox.shrink();
    }
    String? label;
    if (retry != null) {
      label = 'Admission unavailable';
    } else if (admission.requests.isEmpty) {
      label = 'Admission in progress';
    }
    final button = SessionWaitingQueueButton(
      count: admission.requests.length,
      label: label,
      onPressed: () => unawaited(_showSessionAdmission(context, ref)),
    );
    if (child == null) return button;
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [button, child!],
    );
  }
}

Future<void> _showSessionAdmission(BuildContext context, WidgetRef ref) async {
  final open = ref.read(sessionAdmissionOpenProvider.notifier);
  if (shouldDockSessionSidePanel(context)) {
    open.open = !open.open;
    return;
  }
  // Clear any dormant dock selection left by a viewport resize before opening
  // a modal, so widening the window cannot show a second panel beside it.
  open.open = false;
  ref.read(sessionChatOpenProvider.notifier).open = false;
  ref.read(sessionPromptsOpenProvider.notifier).open = false;
  final kind = ViewportResolver.getViewportKind(context);
  if (kind == ViewportKind.mediumSmall || kind == ViewportKind.mediumPlus) {
    await showSessionSidePanelDrawer(
      context,
      settings: const RouteSettings(name: sessionAdmissionRouteName),
      child: const SessionAdmissionPanel(),
    );
    return;
  }
  await showResponsiveModal<void>(
    context: context,
    useRootNavigator: false,
    routeSettings: const RouteSettings(name: sessionAdmissionRouteName),
    showDragHandle: true,
    bottomSheetBackgroundColor: AppTheme.cream,
    dialogBackgroundColor: AppTheme.cream,
    bottomSheetBuilder: (context) => SizedBox(
      height: MediaQuery.heightOf(context) * 0.7,
      child: const SessionAdmissionPanel(),
    ),
    largeScreenBuilder: (context) => const SizedBox(
      width: sessionSidePanelWidth,
      child: SessionAdmissionPanel(),
    ),
  );
}

/// Shared live content for the desktop rail, tablet drawer, and phone sheet.
class SessionAdmissionPanel extends ConsumerWidget {
  const SessionAdmissionPanel({this.docked = false, super.key});

  final bool docked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admission = _SessionAdmissionScope.maybeOf(context);
    if (admission == null) return const SizedBox.shrink();
    void close() {
      if (docked) {
        ref.read(sessionAdmissionOpenProvider.notifier).open = false;
      } else {
        Navigator.of(context).maybePop();
      }
    }

    final retry = admission.onRetry;
    if (retry != null) {
      return Material(
        color: AppTheme.cream,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Could not load declined participants. Admission is paused.',
                  style: TextStyle(color: AppTheme.slate),
                ),
                OutlinedButton(onPressed: retry, child: const Text('Retry')),
                OutlinedButton(onPressed: close, child: const Text('Close')),
              ],
            ),
          ),
        ),
      );
    }
    return Material(
      color: AppTheme.cream,
      elevation: docked ? 6 : 0,
      shadowColor: const Color.fromRGBO(0, 0, 0, 0.16),
      child: SafeArea(
        child: KeeperAdmissionPanel(
          requests: admission.requests,
          attempts: admission.attempts,
          busy: admission.busy,
          embedded: true,
          desktop: docked,
          onDecision: admission.onDecision,
          onDeclinePermanently: admission.onDeclinePermanently,
          onAdmitAll: admission.onAdmitAll,
          onClose: close,
        ),
      ),
    );
  }
}
