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
import 'package:totem_core/features/sessions/admission/keeper_admission_roster.dart';
import 'package:totem_core/features/sessions/admission/session_admission_scope.dart';
import 'package:totem_core/features/sessions/admission/session_admission_settings.dart';
import 'package:totem_core/features/sessions/admission/session_waiting_queue_button.dart';
import 'package:totem_core/features/sessions/controllers/core/session_state.dart';
import 'package:totem_core/features/sessions/controllers/features/session_keeper_controller.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/widgets/session_side_panel.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/confirmation_dialog.dart';
import 'package:totem_core/shared/widgets/notifications.dart';
import 'package:totem_core/shared/widgets/responsive_modal.dart';
import 'package:totem_core/shared/widgets/session_button_style.dart';
import 'package:totem_core/shared/widgets/viewport_resolver.dart';

/// Owns admission connections while the room renders queue controls and panels
/// in its normal layout. Opening or closing a panel never recreates transport.
class SessionAdmissionOverlay extends ConsumerStatefulWidget {
  const SessionAdmissionOverlay({
    required this.sessionSlug,
    required this.child,
    this.now,
    super.key,
  });

  final String sessionSlug;
  final Widget child;
  final DateTime Function()? now;

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
  SessionKeeperController? _sessionKeeper;
  Future<void> Function(String)? _revokeRemovedParticipant;
  ClientAdmissionRosterController? _clientController;
  // Cancelled by _detachAdmission.
  // ignore: cancel_subscriptions
  StreamSubscription<void>? _keeperChanges;
  // Cancelled by _detachAdmission.
  // ignore: cancel_subscriptions
  StreamSubscription<AdmissionRoster?>? _clientChanges;

  Room? _room;
  String? _keeperIdentity;
  KeeperAdmissionRosterStore? _attachedKeeperRoster;
  Future<void> Function()? _saveKeeperRoster;
  Future<void> Function()? _clearKeeperRoster;
  Future<void> Function()? _clearDeclinedParticipants;
  bool _rosterSaveErrorShown = false;
  bool _sessionEnded = false;
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

    unawaited(_detachAdmission(endSession: _sessionEnded));
    _sessionEnded = false;
    _syncAdmission();
  }

  @override
  void dispose() {
    unawaited(
      _detachAdmission(
        clearAdmitted: false,
        endSession: _sessionEnded || (_transport?.hasEnded ?? false),
      ),
    );
    _notificationController.dispose();
    super.dispose();
  }

  void _syncAdmission() {
    if (!mounted) return;
    final state = ref.read(currentSessionStateProvider);
    final event = ref.read(currentSessionEventProvider);
    final session = ref.read(currentSessionProvider);
    final room = session?.room;
    final keeperIdentity = state?.roomState.keeper;
    _sessionEnded =
        state?.roomState.status == RoomStatus.ended || event?.ended == true;
    final connected = state?.connection.state == RoomConnectionState.connected;
    final active =
        connected &&
        state?.roomState.status != RoomStatus.ended &&
        event?.ended != true &&
        room != null &&
        keeperIdentity != null &&
        keeperIdentity.isNotEmpty;
    if (!active) {
      if (_hasAdmission) {
        unawaited(_detachAdmission(endSession: _sessionEnded));
      }
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
    final rosterProvider = keeperAdmissionRosterProvider(
      widget.sessionSlug,
      keeperIdentity,
    );
    final restoredRoster = isKeeper ? ref.read(rosterProvider).value : null;
    // Do not advertise an empty authority before persisted admission is loaded.
    if (isKeeper && (declinedIdentities == null || restoredRoster == null)) {
      if (_hasAdmission &&
          (!identical(_room, room) || _keeperIdentity != keeperIdentity)) {
        unawaited(_detachAdmission());
      }
      return;
    }
    final controllerActive = isKeeper
        ? _keeperController != null
        : _clientController != null;
    if (identical(_room, room) &&
        _keeperIdentity == keeperIdentity &&
        controllerActive &&
        (!isKeeper || identical(_attachedKeeperRoster, restoredRoster))) {
      if (declinedIdentities != null) {
        _keeperController?.setDeclinedIdentities(declinedIdentities);
      }
      _keeperController?.setApprovalRequired(
        ref.read(sessionAdmissionSettingsProvider),
      );
      return;
    }

    unawaited(_detachAdmission(clearAdmitted: !isKeeper));
    final transport = LiveKitAdmissionTransport(room, now: widget.now);
    _transport = transport;
    _room = room;
    _keeperIdentity = keeperIdentity;

    if (isKeeper) {
      _attachedKeeperRoster = restoredRoster;
      final rosterNotifier = ref.read(rosterProvider.notifier);
      _saveKeeperRoster = rosterNotifier.persist;
      _clearKeeperRoster = rosterNotifier.clear;
      _clearDeclinedParticipants = ref
          .read(
            declinedSessionParticipantsProvider(
              widget.sessionSlug,
              keeperIdentity,
            ).notifier,
          )
          .clear;
      final controller = KeeperAdmissionController(
        channel: transport,
        keeperIdentity: _currentKeeperIdentity,
        isSessionStarted: () =>
            ref.read(roomStatusProvider) == RoomStatus.active,
        sessionIdentity: widget.sessionSlug,
        rosterStore: restoredRoster,
        approvalRequired: ref.read(sessionAdmissionSettingsProvider),
        declinedIdentities: declinedIdentities!,
        now: widget.now,
      );
      _keeperController = controller;
      final sessionKeeper = ref.read(
        sessionKeeperControllerProvider(session!).notifier,
      );
      Future<void> revokeRemovedParticipant(String identity) async {
        if (!identical(_keeperController, controller)) {
          throw StateError(
            'Participant was removed, but admission could not be updated.',
          );
        }
        controller.revoke(identity);
        if (!await _persistRoster(rosterNotifier.persist)) {
          throw StateError(
            'Participant was removed, but admission could not be saved.',
          );
        }
      }

      _sessionKeeper = sessionKeeper;
      _revokeRemovedParticipant = revokeRemovedParticipant;
      sessionKeeper.onParticipantRemoved = revokeRemovedParticipant;
      var persistedRosterRevision = controller.rosterRevision;
      final savingRosterRevisions = <int>{};
      _syncAdmittedIdentities(controller.roster);
      _keeperChanges = controller.changes.listen((_) {
        if (!mounted || !identical(_keeperController, controller)) return;
        final revision = controller.rosterRevision;
        final persist = _saveKeeperRoster;
        if (persist != null &&
            revision != persistedRosterRevision &&
            savingRosterRevisions.add(revision)) {
          unawaited(
            _persistRoster(persist).then((saved) {
              savingRosterRevisions.remove(revision);
              if (saved && revision > persistedRosterRevision) {
                persistedRosterRevision = revision;
              }
            }),
          );
        }
        _syncAdmittedIdentities(controller.roster);
        setState(() {});
      });
    } else {
      final controller = ClientAdmissionRosterController(
        channel: transport,
        keeperIdentity: _currentKeeperIdentity,
        sessionIdentity: widget.sessionSlug,
        now: widget.now,
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

  Future<bool> _persistRoster(Future<void> Function() persist) async {
    try {
      await persist();
      _rosterSaveErrorShown = false;
      return true;
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Could not save Keeper admission recovery',
      );
      if (mounted && !_rosterSaveErrorShown) {
        _rosterSaveErrorShown = true;
        _notificationController.showError(
          context,
          icon: TotemIcons.errorOutlined,
          title: 'Admission recovery could not be saved',
          message:
              'Please keep this Session open to avoid losing admission history.',
        );
      }
      return false;
    }
  }

  Future<void> _clearAdmissionData(Future<void> Function() clear) async {
    try {
      await clear();
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Could not clear ended Session admission data',
      );
    }
  }

  void _syncAdmittedIdentities(Iterable<String> identities) {
    final roster = List<String>.of(identities);
    final version = ++_admittedUpdateVersion;
    void update() {
      if (!mounted || version != _admittedUpdateVersion) return;
      _admittedIdentities.update(roster);
      ref
          .read(currentSessionProvider)
          ?.updateAdmittedMediaRecipients(roster.toSet());
    }

    if (WidgetsBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      update();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => update());
    }
  }

  Future<void> _detachAdmission({
    bool clearAdmitted = true,
    bool endSession = false,
  }) {
    if (endSession) {
      final clearRoster = _clearKeeperRoster;
      final clearDeclined = _clearDeclinedParticipants;
      if (clearRoster != null) unawaited(_clearAdmissionData(clearRoster));
      if (clearDeclined != null) unawaited(_clearAdmissionData(clearDeclined));
    } else {
      final persist = _saveKeeperRoster;
      if (persist != null) unawaited(_persistRoster(persist));
    }
    final sessionKeeper = _sessionKeeper;
    if (sessionKeeper != null &&
        identical(
          sessionKeeper.onParticipantRemoved,
          _revokeRemovedParticipant,
        )) {
      sessionKeeper.onParticipantRemoved = null;
    }
    _sessionKeeper = null;
    _revokeRemovedParticipant = null;
    _attachedKeeperRoster = null;
    _saveKeeperRoster = null;
    _clearKeeperRoster = null;
    _clearDeclinedParticipants = null;
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

    final keeperDispose = keeperController?.dispose();
    final clientDispose = clientController?.dispose();
    return Future.wait<void>([
      if (keeperChanges != null) keeperChanges.cancel(),
      if (clientChanges != null) clientChanges.cancel(),
      ?keeperDispose,
      ?clientDispose,
    ]).then((_) => transport?.dispose());
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

  Future<bool> _admitAll() async {
    final controller = _keeperController;
    if (controller == null) return false;
    if (_busy) {
      _notificationController.showTimed(
        context,
        icon: TotemIcons.info,
        title: 'Admission in progress',
        message:
            'Wait for the current admission decision to finish, then try again.',
      );
      return false;
    }
    setState(() => _busy = true);
    var reportedError = false;
    try {
      for (final request in controller.requests) {
        if (!identical(_keeperController, controller)) break;
        reportedError |= await _sendDecision(
          controller,
          request,
          true,
          reportError: !reportedError,
        );
      }
      if (!mounted ||
          !identical(_keeperController, controller) ||
          reportedError) {
        return false;
      }
      if (controller.requests.isEmpty) return true;
      _notificationController.showTimed(
        context,
        icon: TotemIcons.info,
        title: 'New participants arrived',
        message: 'Review the waiting room and try again before starting.',
      );
      return false;
    } finally {
      if (mounted && identical(_keeperController, controller)) {
        setState(() => _busy = false);
      }
    }
  }

  Future<bool> _sendDecision(
    KeeperAdmissionController controller,
    AdmissionRequest request,
    bool approve, {
    bool permanently = false,
    bool reportError = true,
  }) async {
    if (!controller.isPendingRequest(request.id, request.senderIdentity)) {
      return false;
    }
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
      return false;
    } catch (error, stackTrace) {
      if (!controller.isPendingRequest(request.id, request.senderIdentity)) {
        return false;
      }
      if (reportError) {
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
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    VoidCallback? retry;
    Future<void> Function()? resetCorruptData;
    final keeper = ref.watch(keeperIdentityProvider);
    if (keeper != null &&
        ref.read(currentSessionProvider)?.room?.localParticipant?.identity ==
            keeper) {
      final provider = declinedSessionParticipantsProvider(
        widget.sessionSlug,
        keeper,
      );
      final rosterProvider = keeperAdmissionRosterProvider(
        widget.sessionSlug,
        keeper,
      );
      ref
        ..listen(provider, (_, _) => _syncAdmission())
        ..listen(rosterProvider, (_, _) => _syncAdmission());
      final declined = ref.watch(provider);
      final roster = ref.watch(rosterProvider);
      if ((declined.hasError && !declined.hasValue) ||
          (roster.hasError && !roster.hasValue)) {
        retry = () {
          if (declined.hasError) ref.invalidate(provider);
          if (roster.hasError) ref.invalidate(rosterProvider);
        };
        final corruptDeclined =
            declined.error is CorruptSessionAdmissionData && !declined.hasValue;
        final corruptRoster =
            roster.error is CorruptSessionAdmissionData && !roster.hasValue;
        if (corruptDeclined || corruptRoster) {
          resetCorruptData = () async {
            if (corruptDeclined) {
              await ref.read(provider.notifier).resetCorruptData();
            }
            if (corruptRoster) {
              await ref.read(rosterProvider.notifier).resetCorruptData();
            }
          };
        }
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
    final requests = controller?.requests ?? const <AdmissionRequest>[];
    return SessionAdmissionScope(
      requests: requests,
      attempts: attempts,
      enabled: controller?.approvalRequired ?? false,
      busy: _busy,
      onRetry: retry,
      onResetCorruptData: resetCorruptData,
      onDecision: _decide,
      onDeclinePermanently: (request) =>
          _decide(request, false, permanently: true),
      onAdmitAll: _admitAll,
      child: widget.child,
    );
  }
}

const sessionAdmissionRouteName = 'session-admission';

/// A queue control in normal Session layout; it never positions itself over video.
class SessionAdmissionQueueControl extends ConsumerWidget {
  const SessionAdmissionQueueControl({this.child, super.key});

  final Widget? child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admission = SessionAdmissionScope.maybeOf(context);
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
    final admission = SessionAdmissionScope.maybeOf(context);
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
                  'Could not load admission recovery data. Please retry.',
                  style: TextStyle(color: AppTheme.slate),
                ),
                OutlinedButton(
                  onPressed: retry,
                  style: SessionButtonStyle.outlined(),
                  child: const Text('Retry'),
                ),
                if (admission.onResetCorruptData case final reset?)
                  OutlinedButton(
                    style: SessionButtonStyle.outlined(),
                    onPressed: () => showDialog<void>(
                      context: context,
                      useRootNavigator: false,
                      builder: (dialogContext) => ConfirmationDialog(
                        title: 'Reset admission data?',
                        content:
                            'Corrupt admission data will be removed. If the roster is reset, participants must be admitted again. If declined participants are reset, permanent declines will be lost.',
                        confirmButtonText: 'Reset admission data',
                        scrollable: true,
                        onConfirm: () async {
                          try {
                            await reset();
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                          } catch (error, stackTrace) {
                            ErrorHandler.logError(
                              error,
                              stackTrace: stackTrace,
                              message: 'Could not reset admission data',
                            );
                            if (dialogContext.mounted) {
                              ErrorHandler.showErrorDialog(
                                dialogContext,
                                message:
                                    'Could not reset admission data. Please try again.',
                              );
                            }
                          }
                        },
                      ),
                    ),
                    child: const Text('Reset admission data'),
                  ),
                OutlinedButton(
                  onPressed: close,
                  style: SessionButtonStyle.outlined(),
                  child: const Text('Close'),
                ),
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
          onAdmitAll: () => unawaited(admission.onAdmitAll()),
          onClose: close,
        ),
      ),
    );
  }
}
