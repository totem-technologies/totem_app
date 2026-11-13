import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/core/repositories/space_repository.dart';
import 'package:totem_core/features/permissions/media_control.dart';
import 'package:totem_core/features/permissions/media_permission_controller.dart';
import 'package:totem_core/features/permissions/model.dart';
import 'package:totem_core/features/permissions/platform_info.dart';
import 'package:totem_core/features/permissions/policy.dart';
import 'package:totem_core/features/permissions/ui/priming_sheet.dart';
import 'package:totem_core/features/permissions/ui/recovery.dart';
import 'package:totem_core/features/sessions/admission/admission_controllers.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_flow_controller.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_media_controller.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_state.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_view.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/repositories/session_repository.dart';
import 'package:totem_core/features/sessions/screens/error_screen.dart';
import 'package:totem_core/features/sessions/screens/room_screen.dart';
import 'package:totem_core/features/sessions/screens/session_disconnected.dart';
import 'package:totem_core/features/sessions/widgets/background.dart';
import 'package:totem_core/features/sessions/widgets/session_declined_view.dart';

import 'package:totem_core/features/sessions/widgets/transition_card.dart';
import 'package:totem_core/shared/router.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/confirmation_dialog.dart';
import 'package:totem_core/shared/widgets/notifications.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

Future<bool> showAlreadyPresentDialog(BuildContext context) async {
  try {
    return await showDialog<bool>(
          context: context,
          builder: (context) => ConfirmationDialog(
            title: "You're already in this session",
            content:
                'You are already in this session on another device. Do you want to leave the other session and join on this device?',
            icon: TotemIcons.questionMarkCircle,
            iconSize: 60,
            confirmButtonText: 'Join Here',
            onConfirm: () async => Navigator.of(context).pop(true),
            type: ConfirmationDialogType.standard,
          ),
        ) ??
        false;
  } catch (_) {
    return false;
  }
}

/// The note under the join card after a join attempt failed with [error].
String _joinFailureNote(Object? error) {
  final kind = error is SessionJoinFailure ? error.kind : null;
  return switch (kind) {
    SessionErrorCategory.mediaDevice =>
      "We couldn't start your camera or microphone. Check that Totem "
          'can use them and no other app has them open, then try again.',
    SessionErrorCategory.offline ||
    SessionErrorCategory.serverUnreachable ||
    SessionErrorCategory.connectionLost =>
      "We couldn't join the session. Check your connection and try again.",
    _ => "We couldn't join the session. Please try again.",
  };
}

class PreJoinScreen extends ConsumerStatefulWidget {
  const PreJoinScreen({
    required this.sessionSlug,
    this.now = DateTime.now,
    super.key,
  });

  final String sessionSlug;
  final ValueGetter<DateTime> now;

  @override
  ConsumerState<PreJoinScreen> createState() => _PreJoinScreenState();
}

class _PreJoinScreenState extends ConsumerState<PreJoinScreen>
    with WidgetsBindingObserver {
  final GlobalKey _preJoinViewKey = GlobalKey();
  final GlobalKey _previewKey = GlobalKey();
  final GlobalKey _controlsKey = GlobalKey();
  bool _showingAlreadyPresentDialog = false;
  bool _primingSheetShown = false;
  bool _reportedFullyDisplayed = false;
  bool _joined = false;
  bool _leavingWaiting = false;
  bool _wakeLockEnabled = false;
  bool _wakeLockRequested = false;
  bool _signingUpForOffer = false;
  String? _signedUpOfferSlug;
  final _notificationController = NotificationController();
  Future<void> _wakeLockOperation = Future.value();
  PreJoinMediaController? _mediaController;
  bool _terminalMediaReleaseRequested = false;
  Timer? _joinWindowTimer;
  DateTime? _joinWindowStart;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_setWakeLock(enabled: true));
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _joinWindowTimer?.cancel();
    _notificationController.dispose();
    if (!_joined) {
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    }
    unawaited(_setWakeLock(enabled: false));
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_setWakeLock(enabled: true));
    } else if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      unawaited(_setWakeLock(enabled: false));
    }
  }

  Future<void> _setWakeLock({required bool enabled}) {
    if (_wakeLockRequested == enabled && _wakeLockEnabled == enabled) {
      return _wakeLockOperation;
    }
    _wakeLockRequested = enabled;
    return _wakeLockOperation = _wakeLockOperation.then(
      (_) => _applyWakeLock(enabled: enabled),
    );
  }

  Future<void> _applyWakeLock({required bool enabled}) async {
    if (_wakeLockEnabled == enabled) return;
    if (enabled &&
        kIsWeb &&
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    try {
      if (enabled) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
      _wakeLockEnabled = enabled;
    } catch (error, stackTrace) {
      ErrorHandler.report(
        error,
        stackTrace: stackTrace,
        message: 'Failed to update pre-join wake lock',
        disposition: ErrorDisposition.recovered,
        diagnostics: {'feature': 'pre_join', 'wake_lock_enabled': enabled},
      );
    }
  }

  /// Offers the priming sheet once, when access is first known and there's
  /// something the OS can still prompt for. Web capture supplies its prompt.
  void _maybeShowPrimingSheet(MediaPermissions? permissions) {
    if (permissions == null || _primingSheetShown || !mounted) return;
    if (!shouldShowPrimingSheet(permissions, ref.read(platformInfoProvider))) {
      return;
    }
    _primingSheetShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(showMediaPrimingSheet(context));
    });
  }

  void _reportFullyDisplayed() {
    if (_reportedFullyDisplayed || !mounted) return;
    _reportedFullyDisplayed = true;
    SentryDisplayWidget.of(context).reportFullyDisplayed();
  }

  Future<bool> _requestJoin({bool replaceExistingSession = false}) async {
    final outcome = await ref
        .read(preJoinFlowControllerProvider(widget.sessionSlug).notifier)
        .requestJoin(replaceExistingSession: replaceExistingSession);
    if (!mounted) return false;
    if (outcome == PreJoinJoinOutcome.confirmationRequired) {
      await _promptAlreadyPresent();
    }
    return ref.read(preJoinFlowControllerProvider(widget.sessionSlug)).phase ==
        PreJoinFlowPhase.joined;
  }

  Future<void> _promptAlreadyPresent() async {
    if (_showingAlreadyPresentDialog || !mounted) return;
    _showingAlreadyPresentDialog = true;
    final join = await showAlreadyPresentDialog(context);
    _showingAlreadyPresentDialog = false;
    if (!mounted) return;
    if (join) {
      await _requestJoin(replaceExistingSession: true);
    } else if (context.canPop()) {
      context.pop();
    }
  }

  Future<void> _onRetry() async {
    final _ = await ref.refresh(sessionProvider(widget.sessionSlug).future);
  }

  Future<void> _signUpForOffer(String sessionSlug) async {
    if (_signingUpForOffer || !mounted) return;
    setState(() => _signingUpForOffer = true);
    try {
      final attending = await ref.refresh(
        rsvpConfirmProvider(sessionSlug).future,
      );
      if (!mounted) return;
      setState(() {
        _signingUpForOffer = false;
        _signedUpOfferSlug = attending ? sessionSlug : null;
      });
      if (!attending) {
        _notificationController.showError(
          context,
          icon: TotemIcons.spaces,
          title: 'Failed to attend',
          message: 'Please try again later',
        );
      }
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to attend session',
      );
      if (!mounted) return;
      setState(() => _signingUpForOffer = false);
      _notificationController.showError(
        context,
        icon: TotemIcons.spaces,
        title: 'Failed to attend',
        message: 'Please try again later',
      );
    }
  }

  void _scheduleJoinWindow(SessionDetailSchema session) {
    final start = session.start.toLocal().subtract(const Duration(minutes: 10));
    if (_joinWindowStart == start) return;
    _joinWindowStart = start;
    _joinWindowTimer?.cancel();
    final remaining = start.difference(widget.now());
    if (remaining > Duration.zero) {
      _joinWindowTimer = Timer(remaining, () {
        if (mounted) setState(() {});
      });
    }
  }

  Widget _buildDeclined(SessionDetailSchema session, PreJoinFlowState flow) {
    final next = session.space.nextEvents.where(
      (event) =>
          !event.cancelled &&
          event.slug != session.slug &&
          event.start.isAfter(widget.now()),
    );
    final expired = flow.admissionStatus == AdmissionStatus.expired;
    final offer = expired || next.isEmpty ? null : next.first;
    final terminalError = isTerminalSessionJoinError(flow.error);
    final admissionMessage = switch (flow.admissionStatus) {
      AdmissionStatus.denied => 'The Keeper was unable to admit you.',
      AdmissionStatus.ended => 'The Session has ended.',
      AdmissionStatus.expired =>
        'We’re sorry we couldn’t connect you to this session. Please return to the schedule to find another session.',
      _ => null,
    };
    if (!terminalError && admissionMessage == null) {
      ErrorHandler.logError(
        StateError('Unexpected admission status: ${flow.admissionStatus}'),
        message:
            'Unexpected admission outcome for Session ${widget.sessionSlug}',
      );
    }
    final message = terminalError
        ? 'The server is no longer allowing this Session to be joined.'
        : admissionMessage ??
              'This session is unavailable. Please try another session.';
    return RoomBackground(
      status: RoomStatus.ended,
      child: SafeArea(
        child: SessionDeclinedView(
          message: message,
          actionLabel: _signingUpForOffer ? 'Signing up…' : 'Sign up',
          offer: offer == null
              ? null
              : Text(
                  '${offer.title ?? session.space.title} · ${DateFormat('EEEE, MMMM d · h:mm a').format(offer.start.toLocal())}',
                ),
          onOffer: offer == null
              ? null
              : () => context.go(
                  RouteNames.spaceSession(session.space.slug, offer.slug),
                ),
          signedUp:
              (offer?.attending ?? false) || offer?.slug == _signedUpOfferSlug,
          onSignUp: offer == null || offer.attending || _signingUpForOffer
              ? null
              : () => unawaited(_signUpForOffer(offer.slug)),
          backActionLabel: expired ? 'View sessions' : 'Return to the Space',
          onBackToSpace: () {
            if (expired) {
              TotemRouter.instance
                ..setTabCloseConfirmationEnabled(false)
                ..toHome(HomeRoutes.spaces);
            } else {
              TotemRouter.instance.popOrHome(context);
            }
          },
        ),
      ),
    );
  }

  void _releaseTerminalPreviewMedia() {
    final mediaController = _mediaController;
    if (mediaController == null || _terminalMediaReleaseRequested) return;
    _terminalMediaReleaseRequested = true;
    unawaited(mediaController.releaseForTerminalOutcome());
  }

  Widget _buildEligibilityLoading() {
    const media = PreJoinMediaState(
      preferences: PreJoinMediaPreferences(isCameraOn: false, isMicOn: false),
      camera: PreJoinCaptureState(phase: PreJoinCapturePhase.disabled),
      microphone: PreJoinCaptureState(phase: PreJoinCapturePhase.disabled),
    );
    return PreJoinView(
      key: _preJoinViewKey,
      mediaState: media,
      locked: true,
      onToggleCamera: Future<void>.value,
      onToggleMicrophone: Future<void>.value,
      onToggleSpeaker: () {},
      onCameraFacingChanged: (_) {},
      onCameraDeviceSelected: (_) {},
      joinCard: JoinTransitionCard(
        margin: const EdgeInsetsDirectional.symmetric(horizontal: 10),
        onActionPressed: () => Future.value(false),
        enabled: false,
      ),
      previewKey: _previewKey,
      controlsKey: _controlsKey,
    );
  }

  Widget _buildEndedScreen(SessionDetailSchema session) {
    _releaseTerminalPreviewMedia();
    return RoomBackground(
      status: RoomStatus.ended,
      child: SessionDisconnectedScreen(
        session: session,
        sessionDisconnectedReason: SessionDisconnectedReason.keeperEnded,
      ),
    );
  }

  Widget _buildErrorScreen(Object? error, {SessionDetailSchema? session}) {
    return RoomBackground(
      child: SessionErrorScreen(
        error: error,
        session: session,
        onRetry: _onRetry,
      ),
    );
  }

  /// The preview's [kind], for the shared turn-on and recovery flow.
  MediaControl _control(MediaKind kind) {
    final provider = preJoinMediaControllerProvider(widget.sessionSlug);
    return MediaControl(
      kind: kind,
      problem: provider.select(
        (media) => switch (kind) {
          MediaKind.camera => media.camera.problem,
          MediaKind.microphone => media.microphone.problem,
        },
      ),
      turnOn: () async {
        if (mounted) return await ref.read(provider.notifier).turnOn(kind);
        return const TurnOnSkipped();
      },
    );
  }

  Future<void> _toggleMedia(MediaKind kind, {required bool isOn}) async {
    if (isOn) {
      await ref
          .read(preJoinMediaControllerProvider(widget.sessionSlug).notifier)
          .turnOff(kind);
      return;
    }
    await turnOnMedia(
      context,
      ref,
      _control(kind),
      explain: kind != MediaKind.microphone,
    );
  }

  Widget _buildPreJoinView(
    PreJoinMediaState media,
    PreJoinFlowState flow,
    SessionDetailSchema session, {
    required bool early,
    required String? participantName,
  }) {
    final mediaController = ref.read(
      preJoinMediaControllerProvider(widget.sessionSlug).notifier,
    );
    _mediaController = mediaController;
    final permissions = ref.watch(mediaPermissionControllerProvider);
    _maybeShowPrimingSheet(permissions);
    final readiness = joinReadiness(
      permissions: permissions,
      microphoneProblem: media.microphone.problem,
      mediaSettled: media.initializationComplete,
    );
    if (readiness != JoinReadiness.checking && !_reportedFullyDisplayed) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _reportFullyDisplayed(),
      );
    }
    final pending = flow.phase == PreJoinFlowPhase.pending;
    String? joinNote;
    if (early) {
      joinNote =
          'Join opens at ${DateFormat('h:mm a').format(session.start.toLocal().subtract(const Duration(minutes: 10)))}.';
    } else if (flow.error != null) {
      joinNote = flow.admissionStatus == AdmissionStatus.failed
          ? 'Waiting room connection was lost. Check your connection and try again.'
          : _joinFailureNote(flow.error);
    }
    final waitingMessage = switch (flow.keeperAvailability) {
      AdmissionKeeperAvailability.unresponsive =>
        "The Keeper hasn't confirmed your request. Ask them to reconnect or update Totem, or leave and try again.",
      _ => null,
    };
    void leaveWaiting() {
      if (_leavingWaiting) return;
      _leavingWaiting = true;
      unawaited(() async {
        await ref
            .read(preJoinFlowControllerProvider(widget.sessionSlug).notifier)
            .cancelAdmission();
        if (!mounted) return;
        TotemRouter.instance
          ..setTabCloseConfirmationEnabled(false)
          ..popOrHome(context);
      }());
    }

    return PreJoinView(
      key: _preJoinViewKey,
      mediaState: media,
      onLeave: pending ? leaveWaiting : null,
      locked:
          (flow.phase != PreJoinFlowPhase.idle &&
              flow.phase != PreJoinFlowPhase.pending) ||
          !media.initializationComplete,
      onToggleCamera: () =>
          _toggleMedia(MediaKind.camera, isOn: media.preferences.isCameraOn),
      onToggleMicrophone: () =>
          _toggleMedia(MediaKind.microphone, isOn: media.preferences.isMicOn),
      onToggleSpeaker: mediaController.toggleSpeaker,
      onCameraFacingChanged: mediaController.setCameraFacing,
      onCameraDeviceSelected: mediaController.selectCameraDevice,
      previewKey: _previewKey,
      controlsKey: _controlsKey,
      notice: readiness == JoinReadiness.microphoneNeeded
          ? MediaRecoveryBanner(control: _control(MediaKind.microphone))
          : null,
      joinCard: JoinTransitionCard(
        margin: const EdgeInsetsDirectional.symmetric(horizontal: 10),
        keepActionLoadingOnSuccess: true,
        enabled: readiness == JoinReadiness.ready && !early,
        onActionPressed: early ? () async => false : _requestJoin,
        isSliderLoading: flow.phase == PreJoinFlowPhase.joining,
        note: joinNote,
        welcomeName: participantName,
        waiting: pending,
        waitingMessage: waitingMessage,
        onLeaveWaiting: leaveWaiting,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionData = ref.watch(sessionProvider(widget.sessionSlug));
    if (sessionData.hasError) {
      if (isTerminalSessionJoinError(sessionData.error)) {
        _releaseTerminalPreviewMedia();
      }
      return _buildErrorScreen(sessionData.error);
    }

    final loadingData = sessionData.isLoading && !sessionData.isRefreshing;
    if (loadingData) return _buildEligibilityLoading();

    final session = sessionData.value;
    if (session?.ended ?? false) return _buildEndedScreen(session!);

    final flow = ref.watch(preJoinFlowControllerProvider(widget.sessionSlug));
    if (session == null) return _buildEligibilityLoading();
    _scheduleJoinWindow(session);
    final keeperIdentity = session.space.author.slug.value;
    final user = ref.watch(authControllerProvider).user;
    final isKeeper =
        keeperIdentity != null && keeperIdentity == user?.slug.value;
    final displayName = user?.name.value?.trim();
    final participantName = displayName == null || displayName.isEmpty
        ? null
        : displayName;
    final early =
        !isKeeper &&
        widget.now().isBefore(
          session.start.subtract(const Duration(minutes: 10)),
        );
    if (isTerminalSessionJoinError(flow.error) ||
        flow.admissionStatus == AdmissionStatus.denied ||
        flow.admissionStatus == AdmissionStatus.expired ||
        flow.admissionStatus == AdmissionStatus.ended) {
      return _buildDeclined(session, flow);
    }
    final media = ref.watch(preJoinMediaControllerProvider(widget.sessionSlug));
    _joined = flow.phase == PreJoinFlowPhase.joined;

    final preJoinView = _buildPreJoinView(
      media,
      flow,
      session,
      early: early,
      participantName: participantName,
    );
    final hasStartedJoin =
        flow.phase != PreJoinFlowPhase.idle && flow.sessionOptions != null;
    if (!hasStartedJoin || loadingData) {
      return preJoinView;
    }

    return ProviderScope(
      overrides: [
        sessionScopeProvider.overrideWith((_) => flow.sessionOptions!),
      ],
      child: VideoSessionScreen(
        sessionSlug: widget.sessionSlug,
        loadingScreen: preJoinView,
        showAdmissionOrientation:
            flow.admissionStatus == AdmissionStatus.approved,
        admissionReady: flow.phase == PreJoinFlowPhase.joined,
        isReturningParticipant: flow.isReturningParticipant,
        sessionStartedAtAdmission: flow.sessionStartedAtAdmission,
      ),
    );
  }
}
